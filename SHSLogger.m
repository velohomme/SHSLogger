// The MIT License (MIT)
//
//  SHSLogger.m
//
//  Copyright (c) 2013 Summit Hill Software. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "SHSLogger.h"

#define kLogFolder @"AppLogs"
#define kLogPrefix @"AppLog-%@"
#define kLogSuffix @"log"
#define kLogFileSize 500000

@interface SHSLogger()

@property (nonatomic, strong) NSString* currentLogFilePath;
@property (nonatomic, strong) NSString* logAPath;
@property (nonatomic, strong) NSString* logBPath;
@property (nonatomic, strong) NSString* logsDirectory;

@end

@implementation SHSLogger

static SHSLogger *sharedInstance = nil;

+ (SHSLogger *)sharedLogger {
    if (nil != sharedInstance) {
        return sharedInstance;
    }
    
    static dispatch_once_t pred;        
    dispatch_once(&pred, ^{             
        sharedInstance = [[SHSLogger alloc] init];
    });
    
    return sharedInstance;
}

-(void)log: (NSString*)message {
    [self appendToLog: [NSString stringWithFormat:@"%@: %@\n", [NSDate date], message]];
}

-(NSArray*)filesInDateAscendingOrder {
    NSMutableArray* filePaths = [NSMutableArray array];
    NSString* lastFilePath = [self lastLogWrittenToFilePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:lastFilePath]) {
        [filePaths addObject:lastFilePath];
    }
    NSString* otherFile = [lastFilePath isEqualToString:self.logAPath] ? self.logBPath : self.logAPath;
    if ([[NSFileManager defaultManager] fileExistsAtPath:otherFile]) {
        [filePaths addObject:otherFile];
    }
    return [[filePaths reverseObjectEnumerator] allObjects];
}

#pragma mark Private

- (id)init
{
    self = [super init];
    if (self) {
        [self initFilePaths];
    }
    return self;
}

-(void)appendToLog: (NSString*)record {
    NSData* recordAsData = [record dataUsingEncoding:NSUTF8StringEncoding];
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.currentLogFilePath]) {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.currentLogFilePath];
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:recordAsData];
        [fileHandle closeFile];
        [self switchLogsIfNeeded];
    } else {
        NSError* error;
        [recordAsData writeToFile:self.currentLogFilePath options:NSDataWritingAtomic error:&error];
        if(error != nil) {
            NSLog(@"error writing to log: %@", error);
        }
    }
}

-(void)initFilePaths {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [paths objectAtIndex:0];
    self.logsDirectory = [cacheDir stringByAppendingPathComponent: kLogFolder];
    NSError *error;
	if (![[NSFileManager defaultManager] fileExistsAtPath:self.logsDirectory]) {
		if (![[NSFileManager defaultManager] createDirectoryAtPath:self.logsDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
			NSLog(@"Error creating leaguevine event submit log: %@", error);
		}
	}
    self.logAPath = [self getFilePathForLog: @"A"];
    self.logBPath = [self getFilePathForLog: @"B"];
}

-(NSString*)getFilePathForLog: (NSString*)logSuffix {
    return [[self.logsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:kLogPrefix, logSuffix]] stringByAppendingPathExtension:kLogSuffix];
}

-(NSString*)currentLogFilePath {
    if (!_currentLogFilePath) {
        _currentLogFilePath = [self lastLogWrittenToFilePath];
    }
    return _currentLogFilePath;
}

-(NSString*)lastLogWrittenToFilePath {
    NSDate* logADate;
    NSDate* logBDate;
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.logAPath]) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.logAPath error:nil];
        logADate = [attributes fileModificationDate];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.logBPath]) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.logBPath error:nil];
        logBDate = [attributes fileModificationDate];
    }
    if (!logBDate) {
        return self.logAPath;
    } else if (!logADate) {
        return self.logBPath;
    } else {
        return [logADate compare:logBDate] == NSOrderedAscending ? self.logBPath : self.logAPath;
    }
}

-(void)switchLogsIfNeeded {
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.currentLogFilePath]) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.currentLogFilePath error:nil];
        long long size = [attributes fileSize];
        if (size > kLogFileSize) {
            [self switchLogs];
        }
    }
}

-(void)switchLogs {
    self.currentLogFilePath = [self.currentLogFilePath isEqualToString:self.logAPath] ? self.logBPath : self.logAPath;
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.currentLogFilePath]) {
        NSError *error;
        if (![[NSFileManager defaultManager] removeItemAtPath:self.currentLogFilePath error:&error]) {
			NSLog(@"Delete file error: %@", error);
		}
    }
}

-(NSString*)logFileContents {
    NSArray* filePaths = [self filesInDateAscendingOrder];
    NSMutableString* s = [NSMutableString string];
    for (NSString* path in filePaths) {
        NSError* error;
        NSString* fileContents = [NSString stringWithContentsOfFile: path encoding:NSUTF8StringEncoding error:&error];
        if (!error) {
            [s appendString:fileContents];
        }
    }
    return s;
}

@end
