//
//  AudioFile.h
//  Carputer
//
//  Created by Guy Powell on 05/01/2014.
//  Copyright (c) 2014 Guytp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface AudioFile : NSManagedObject

@property (nonatomic, retain) NSNumber * id;
@property (nonatomic, retain) NSString * artist;
@property (nonatomic, retain) NSString * album;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * trackNumber;
@property (nonatomic, retain) NSNumber * duration;
@property (nonatomic, retain) NSString * device;
@property (nonatomic, retain) NSDate * lastSeen;
@property (nonatomic, retain) NSNumber * seenInLastSync;
@property (nonatomic, retain) NSNumber * playCount;
@property (nonatomic, retain) NSNumber * isOnline;

@end
