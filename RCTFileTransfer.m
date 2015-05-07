//
//  RCTFileTransfer.m
//  react-native-file-transfer
//
//  Created by Kamil Pękala on 30.04.2015
//  Copyright (c) 2015 Kamil Pękala. All rights reserved.
//

#import "RCTBridgeModule.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <UIKit/UIKit.h>
@interface FileTransfer : NSObject <RCTBridgeModule>
- (NSMutableURLRequest *)getMultiPartRequest:(NSData *)fileData serverUrl:(NSString *)server requestData:(NSDictionary *)requestData mimeType:(NSString *)mimeType fileName:(NSString *)fileName;
- (void)uploadAssetsLibrary:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback;
- (void)uploadUri:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback;
- (void)uploadFile:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback;
- (void)sendFileData:(NSData *)fileData withOptions:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback;
@end

@implementation FileTransfer

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(upload:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback)
{
  NSString *url = input[@"path"];
  if([url hasPrefix:@"assets-library"]){
    [self uploadAssetsLibrary:input callback:callback];
  }
  else if([url hasPrefix:@"data:"]){
    [self uploadUri:input callback:callback];
  }
  else if([url hasPrefix:@"file:"]){
    [self uploadUri:input callback:callback];
  }
  else if ([url isAbsolutePath]) {
    [self uploadFile:input callback:callback];
  }
  else{
    NSDictionary *res=[[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInteger:0],@"status",@"Unknown protocol",@"data",nil];
    callback(@[res]);
  }
}

- (void)uploadAssetsLibrary:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{

  NSURL *url = [[NSURL alloc] initWithString:input[@"path"]];
  NSString *fileName = input[@"fileName"];
  NSString *mimeType = input[@"mimeType"];
  NSString *uploadUrl = input[@"uploadUrl"];

  ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];

  // Using the ALAssetsLibrary instance and our NSURL object open the image.
  [library assetForURL:url resultBlock:^(ALAsset *asset) {

    ALAssetRepresentation *rep = [asset defaultRepresentation];

    CGImageRef fullScreenImageRef = [rep fullScreenImage];
    UIImage *image = [UIImage imageWithCGImage:fullScreenImageRef];
    NSData *fileData = UIImagePNGRepresentation(image);

//    Byte *buffer = (Byte*)malloc(rep.size);
//    NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
//
//    NSData *fileData = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
    NSDictionary* requestData = [input objectForKey:@"data"];
    NSMutableURLRequest* req = [self getMultiPartRequest:fileData serverUrl:uploadUrl requestData:requestData mimeType:mimeType fileName:fileName];

    NSHTTPURLResponse *response = nil;
    NSData *returnData = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:nil];
    NSInteger statusCode = [response statusCode];
    NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];

    NSDictionary *res=[[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInteger:statusCode],@"status",returnString,@"data",nil];

    callback(@[res]);

  } failureBlock:^(NSError *error) {
    NSLog(@"Getting file from library failed: %@", error);
  }];
}

- (void)uploadFile:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
  NSURL *filePath = [[NSURL alloc] initWithString:input[@"path"]];
  NSData *fileData = [NSData dataWithContentsOfFile:filePath];

  [self sendFileData:fileData withOptions:input callback:callback];
}

- (void)uploadUri:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
  NSString *dataUrlString = input[@"path"];
  NSURL *dataUrl = [[NSURL alloc] initWithString:dataUrlString];
  NSData *fileData = [NSData dataWithContentsOfURL: dataUrl];

  [self sendFileData:fileData withOptions:input callback:callback];
}

- (void)sendFileData:(NSData *)fileData withOptions:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
  NSString *fileName = input[@"fileName"];
  NSString *mimeType = input[@"mimeType"];
  NSString *uploadUrl = input[@"uploadUrl"];

  NSDictionary* requestData = [input objectForKey:@"data"];
  NSMutableURLRequest* req = [self getMultiPartRequest:fileData serverUrl:uploadUrl requestData:requestData mimeType:mimeType fileName:fileName];

  NSHTTPURLResponse *response = nil;
  NSData *returnData = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:nil];
  NSInteger statusCode = [response statusCode];
  NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];

  NSDictionary *res=[[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInteger:statusCode],@"status",returnString,@"data",nil];

  callback(@[res]);
}

- (NSMutableURLRequest *)getMultiPartRequest:(NSData *)fileData serverUrl:(NSString *)server requestData:(NSDictionary *)requestData mimeType:(NSString *)mimeType fileName:(NSString *)fileName
{
  NSString* fileKey = @"file";
  NSURL* url = [NSURL URLWithString:server];
  NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:url];

  [req setHTTPMethod:@"POST"];

  NSString* formBoundaryString = @"----react.file.transfer.form.boundary";

  NSString* contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", formBoundaryString];
  [req setValue:contentType forHTTPHeaderField:@"Content-Type"];

  NSData* formBoundaryData = [[NSString stringWithFormat:@"--%@\r\n", formBoundaryString] dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableData* requestBody = [NSMutableData data];

  for (NSString* key in requestData) {
    id val = [requestData objectForKey:key];
    if ([val respondsToSelector:@selector(stringValue)]) {
      val = [val stringValue];
    }
    if (![val isKindOfClass:[NSString class]]) {
      continue;
    }

    [requestBody appendData:formBoundaryData];
    [requestBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
    [requestBody appendData:[val dataUsingEncoding:NSUTF8StringEncoding]];
    [requestBody appendData:[@"\r\n" dataUsingEncoding : NSUTF8StringEncoding]];
  }

  [requestBody appendData:formBoundaryData];
  [requestBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", fileKey, fileName] dataUsingEncoding:NSUTF8StringEncoding]];
  if (mimeType != nil) {
    [requestBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n", mimeType] dataUsingEncoding:NSUTF8StringEncoding]];
  }
  [requestBody appendData:[[NSString stringWithFormat:@"Content-Length: %ld\r\n\r\n", (long)[fileData length]] dataUsingEncoding:NSUTF8StringEncoding]];

  NSData* afterFile = [[NSString stringWithFormat:@"\r\n--%@--\r\n", formBoundaryString] dataUsingEncoding:NSUTF8StringEncoding];

  long long totalPayloadLength = [requestBody length] + [fileData length] + [afterFile length];
  [req setValue:[[NSNumber numberWithLongLong:totalPayloadLength] stringValue] forHTTPHeaderField:@"Content-Length"];

  [requestBody appendData:fileData];
  [requestBody appendData:afterFile];
  [req setHTTPBody:requestBody];
  return req;
}

@end
