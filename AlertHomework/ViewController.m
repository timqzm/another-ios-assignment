//
//  ViewController.m
//  AlertHomework
//
//  Created by Erkki Nokso+Koivisto on 04/12/2018.
//  Copyright © 2018 In4mo. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    Alert *alert = [Alert makeWithTitle:@"Hey" message:@"First"];
    [alert addCancelWithTitle:@"Cancel" handler:nil];
    [alert showWithAnimated:true behavior:DisplayingBehaviorDefault completion:nil];
    
    [[Alert makeWithTitle:@"Hey" message:@"Second"] postponePresentationWithAnimated:true completion:nil];
}

@end
