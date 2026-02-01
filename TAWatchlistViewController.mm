/**
 * TAWatchlistViewController.mm
 */

#import "TAWatchlistViewController.h"
#import "TACoinbaseAPI.h"
#import "TAGlassCardView.h"
#import <QuartzCore/QuartzCore.h>

@interface TAWatchlistViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) UIView *watchlistCard;
@property (nonatomic, strong) UILabel *watchlistLabel;
@property (nonatomic, strong) UILabel *updatedLabel;
@end

@implementation TAWatchlistViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Watchlist";
    self.view.backgroundColor = [UIColor blackColor];

    [self setupUI];
    [self refreshWatchlist];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshWatchlist];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    self.gradientLayer.frame = self.view.bounds;

    CGFloat width = self.view.bounds.size.width;
    CGFloat margin = 20;
    CGFloat y = 16;

    self.watchlistCard.frame = CGRectMake(margin, y, width - margin * 2, 360);
    self.watchlistLabel.frame = CGRectMake(16, 16, self.watchlistCard.bounds.size.width - 32, 300);
    self.updatedLabel.frame = CGRectMake(16, 318, self.watchlistCard.bounds.size.width - 32, 20);

    self.scrollView.contentSize = CGSizeMake(width, y + 400);
}

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.scrollView];

    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.colors = @[(id)[UIColor colorWithRed:0.05 green:0.06 blue:0.10 alpha:1.0].CGColor,
                                  (id)[UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0].CGColor];
    self.gradientLayer.startPoint = CGPointMake(0, 0);
    self.gradientLayer.endPoint = CGPointMake(1, 1);
    [self.view.layer insertSublayer:self.gradientLayer atIndex:0];

    self.watchlistCard = [[TAGlassCardView alloc] initWithFrame:CGRectZero];
    [self.scrollView addSubview:self.watchlistCard];

    self.watchlistLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.watchlistLabel.textColor = [UIColor lightGrayColor];
    self.watchlistLabel.font = [UIFont systemFontOfSize:12];
    self.watchlistLabel.numberOfLines = 0;
    self.watchlistLabel.text = @"Loading watchlist...";
    [self.watchlistCard addSubview:self.watchlistLabel];

    self.updatedLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.updatedLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    self.updatedLabel.font = [UIFont systemFontOfSize:11];
    self.updatedLabel.text = @"";
    [self.watchlistCard addSubview:self.updatedLabel];
}

- (void)refreshWatchlist {
    [[TACoinbaseAPI sharedInstance] getProducts:^(NSArray *products, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                self.watchlistLabel.text = [NSString stringWithFormat:@"Watchlist\n%@", error.localizedDescription ?: @"Failed to load"];
                return;
            }
            NSMutableArray<NSString *> *lines = [NSMutableArray array];
            NSInteger count = MIN(12, products.count);
            for (NSInteger i = 0; i < count; i++) {
                NSDictionary *product = products[i];
                NSString *symbol = product[@"product_id"] ?: product[@"id"] ?: @"--";
                NSString *price = product[@"price"] ?: @"--";
                NSString *change = product[@"price_percentage_change_24h"] ?: product[@"change_24h"] ?: @"--";
                if (change.length > 0 && ![change containsString:@"%"] && ![change isEqualToString:@"--"]) {
                    change = [NSString stringWithFormat:@"%@%%", change];
                }
                NSString *line = [NSString stringWithFormat:@"%@  %@  (%@)", symbol, price, change];
                [lines addObject:line];
            }
            self.watchlistLabel.text = lines.count > 0 ? [lines componentsJoinedByString:@"\n"] : @"No products available";
            self.updatedLabel.text = [NSString stringWithFormat:@"Updated: %@", [[NSDate date] description]];
        });
    }];
}

@end

