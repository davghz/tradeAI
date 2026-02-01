#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TAOpenRouterClient : NSObject
+ (instancetype)sharedInstance;
- (void)setAPIKey:(NSString *)apiKey;
- (void)setModel:(NSString *)modelId;

- (void)requestRecommendationForSymbol:(NSString *)symbol
                                 price:(NSString *)price
                               accounts:(NSArray<NSDictionary *> *)accounts
                             completion:(void (^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
