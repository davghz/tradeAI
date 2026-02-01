#import "TAOpenRouterClient.h"
#import "TATradeJournal.h"
#import "TAJournalStorage.h"

static NSString *const kOpenRouterBaseURL = @"https://openrouter.ai/api/v1/chat/completions";

@interface TAOpenRouterClient ()
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *model;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation TAOpenRouterClient

+ (instancetype)sharedInstance {
    static TAOpenRouterClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        config.timeoutIntervalForResource = 60.0;
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (void)setAPIKey:(NSString *)apiKey {
    _apiKey = [apiKey copy];
}

- (void)setModel:(NSString *)modelId {
    _model = [modelId copy];
}

- (NSString *)systemPrompt {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *strategy = [defaults stringForKey:@"openrouter_strategy"] ?: @"balanced";
    NSString *customPrompt = [defaults stringForKey:@"openrouter_custom_prompt"] ?: @"";
    NSString *basePrompt = @"You are a balanced trading assistant. Use concise technical analysis. Reply with BUY, SELL, or HOLD and one sentence rationale.";

    if ([strategy isEqualToString:@"conservative"]) {
        basePrompt = @"You are a conservative trading assistant. Prioritize capital preservation and risk management. Reply with BUY, SELL, or HOLD and one sentence rationale including risk level.";
    } else if ([strategy isEqualToString:@"aggressive"]) {
        basePrompt = @"You are an aggressive trading assistant. Focus on momentum, breakouts, and volume spikes. Reply with BUY, SELL, or HOLD and one sentence rationale with a profit target.";
    } else if ([strategy isEqualToString:@"custom"] && customPrompt.length > 0) {
        basePrompt = customPrompt;
    }

    NSString *jsonInstruction = @"Respond ONLY with valid JSON: {\"action\":\"BUY|SELL|HOLD\",\"confidence\":0-100,\"rationale\":\"...\"}.";
    return [NSString stringWithFormat:@"%@\n%@", basePrompt, jsonInstruction];
}

- (NSDictionary *)parseAIResponseContent:(NSString *)content {
    NSString *trim = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trim hasPrefix:@"```"]) {
        NSRange start = [trim rangeOfString:@"\n"];
        if (start.location != NSNotFound) {
            trim = [trim substringFromIndex:start.location + 1];
        }
        NSRange end = [trim rangeOfString:@"```" options:NSBackwardsSearch];
        if (end.location != NSNotFound) {
            trim = [trim substringToIndex:end.location];
        }
        trim = [trim stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    NSString *action = nil;
    NSString *rationale = nil;
    NSNumber *confidence = nil;

    NSData *jsonData = [trim dataUsingEncoding:NSUTF8StringEncoding];
    if (jsonData) {
        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
        if ([json isKindOfClass:[NSDictionary class]] && !jsonError) {
            NSDictionary *dict = (NSDictionary *)json;
            action = dict[@"action"] ?: dict[@"decision"];
            rationale = dict[@"rationale"] ?: dict[@"reason"];
            id conf = dict[@"confidence"];
            if ([conf respondsToSelector:@selector(doubleValue)]) {
                confidence = @([conf doubleValue]);
            }
        }
    }

    if (!action) {
        NSString *upper = [content uppercaseString];
        if ([upper containsString:@"BUY"]) {
            action = @"BUY";
        } else if ([upper containsString:@"SELL"]) {
            action = @"SELL";
        } else if ([upper containsString:@"HOLD"]) {
            action = @"HOLD";
        }
    }

    if (!confidence) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"confidence\\s*[:=]?\\s*(\\d+(?:\\.\\d+)?)" options:NSRegularExpressionCaseInsensitive error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:content options:0 range:NSMakeRange(0, content.length)];
        if (match.numberOfRanges > 1) {
            NSString *valueStr = [content substringWithRange:[match rangeAtIndex:1]];
            double value = valueStr.doubleValue;
            if (value > 0 && value <= 1.0) {
                value *= 100.0;
            }
            confidence = @(value);
        }
    }

    if (!confidence) {
        NSRegularExpression *percentRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{1,3})\\s*%" options:0 error:nil];
        NSTextCheckingResult *percentMatch = [percentRegex firstMatchInString:content options:0 range:NSMakeRange(0, content.length)];
        if (percentMatch.numberOfRanges > 1) {
            NSString *valueStr = [content substringWithRange:[percentMatch rangeAtIndex:1]];
            confidence = @([valueStr doubleValue]);
        }
    }

    if (!rationale) {
        rationale = content;
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    if (action) {
        result[@"action"] = [action uppercaseString];
    }
    if (confidence) {
        result[@"confidence"] = confidence;
    }
    if (rationale) {
        result[@"rationale"] = rationale;
    }
    result[@"raw"] = content ?: @"";
    return result;
}

- (void)requestRecommendationForSymbol:(NSString *)symbol
                                 price:(NSString *)price
                               accounts:(NSArray<NSDictionary *> *)accounts
                             completion:(void (^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion {
    if (self.apiKey.length == 0 || self.model.length == 0) {
        NSError *error = [NSError errorWithDomain:@"OpenRouter" code:401 userInfo:@{NSLocalizedDescriptionKey: @"OpenRouter not configured"}];
        completion(nil, error);
        return;
    }

    NSMutableArray *messages = [NSMutableArray array];
    [messages addObject:@{ @"role": @"system",
                           @"content": [self systemPrompt] }];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *strategy = [defaults stringForKey:@"openrouter_strategy"] ?: @"balanced";
    BOOL riskEnabled = [defaults boolForKey:@"risk_controls_enabled"];
    NSString *stopLoss = [defaults stringForKey:@"risk_stop_loss"] ?: @"--";
    NSString *takeProfit = [defaults stringForKey:@"risk_take_profit"] ?: @"--";
    NSString *riskLine = riskEnabled ? [NSString stringWithFormat:@"Risk: stop_loss=%@%%, take_profit=%@%%", stopLoss, takeProfit] : @"Risk: disabled";

    NSString *summary = [NSString stringWithFormat:@"Symbol: %@\nPrice: %@\nStrategy: %@\n%@\nAccounts: %@",
                         symbol, price ?: @"--", strategy, riskLine, accounts ?: @[]];
    [messages addObject:@{ @"role": @"user", @"content": summary }];

    NSDictionary *payload = @{
        @"model": self.model,
        @"messages": messages,
        @"temperature": @0.2
    };

    NSError *jsonError = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (!bodyData) {
        completion(nil, jsonError);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kOpenRouterBaseURL]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.apiKey] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"TradeAI" forHTTPHeaderField:@"X-Title"];
    [request setHTTPBody:bodyData];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSError *parseError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (!json || parseError) {
            completion(nil, parseError);
            return;
        }
        if ([json[@"error"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *errorInfo = json[@"error"];
            NSString *message = errorInfo[@"message"] ?: @"OpenRouter error";
            NSError *apiError = [NSError errorWithDomain:@"OpenRouter" code:500 userInfo:@{NSLocalizedDescriptionKey: message}];
            completion(nil, apiError);
            return;
        }

        id contentObj = json[@"choices"][0][@"message"][@"content"];
        NSString *content = nil;
        if ([contentObj isKindOfClass:[NSString class]]) {
            content = (NSString *)contentObj;
        } else if ([contentObj isKindOfClass:[NSDictionary class]] || [contentObj isKindOfClass:[NSArray class]]) {
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:contentObj options:0 error:nil];
            content = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : [contentObj description];
        } else if ([contentObj respondsToSelector:@selector(stringValue)]) {
            content = [contentObj stringValue];
        } else if (contentObj) {
            content = [contentObj description];
        }

        if (content.length == 0) {
            NSError *emptyError = [NSError errorWithDomain:@"OpenRouter" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Empty response"}];
            completion(nil, emptyError);
            return;
        }
        NSDictionary *parsed = [self parseAIResponseContent:content];

        // Log AI decision to trade journal
        TATradeJournal *entry = [TATradeJournal entryWithSymbol:symbol];
        entry.priceAtDecision = price.length > 0 ? [NSDecimalNumber decimalNumberWithString:price] : nil;
        entry.aiModel = self.model;
        entry.aiStrategy = [[NSUserDefaults standardUserDefaults] stringForKey:@"openrouter_strategy"] ?: @"balanced";
        entry.aiAction = parsed[@"action"];
        entry.aiConfidence = parsed[@"confidence"];
        entry.aiRationale = parsed[@"rationale"];
        [[TAJournalStorage sharedInstance] saveEntry:entry];

        // Include entryId in response for trade linking
        NSMutableDictionary *result = [parsed mutableCopy];
        result[@"journalEntryId"] = entry.entryId;

        completion(result, nil);
    }];
    [task resume];
}

@end
