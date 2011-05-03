//
//  RestfulGallery.m
//  Tutorial
//
//  Created by Scott Selberg on 3/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RestfulGallery.h"


@implementation RestfulGallery
@synthesize url;
@synthesize userAgent;
@synthesize galleryApiKey;
@synthesize beVerbose;
@synthesize encoding;
@synthesize galleryConnection;
@synthesize results;

- (RestfulGallery *)init;
{
    self = [super init];
    if( self )
    { 
        self.userAgent         = @"ApertureToGallery3ExportPlugin";
        self.encoding          = NSASCIIStringEncoding;
        self.galleryConnection = [GalleryConnection alloc];
        self.beVerbose = false;
        addPhotoQueue = [[NSMutableArray alloc] init];
    }
    
    return self;    
}

- (void)dealloc
{
    self.userAgent         = nil;
    self.galleryApiKey     = nil;
    self.url               = nil;
    self.galleryConnection = nil;
    self.results           = nil;

    [addPhotoQueue release];
    addPhotoQueue = nil;
    
    [super dealloc];
}

- (void)cancel
{
    [galleryConnection cancel];
}


- (void)got:(NSMutableDictionary *)myResults;
{
    self.results = myResults;

//    NSLog( @"%@", results );
//    NSLog( @"Done!" );

    [self processAddPhotoQueue];
}

- (void)getApiKeyforGallery:(NSString *)myGallery AndUsername:(NSString *)username AndPassword:(NSString *)password;
{    
    if( [self beVerbose] ){ NSLog( @"getting API" ); }
    results = nil;
    //build the request
    NSURL *localURL = [[[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@/index.php/rest", myGallery]] autorelease];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:localURL
                                                        cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                        timeoutInterval:60.0];
	[request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"post"        forHTTPHeaderField:@"X-Gallery-Request-Method"];
	[request setHTTPMethod:@"POST"];
    
    NSString *requestString = [NSString stringWithFormat:@"user=%@&password=%@", username, password];
    NSData   *requestData   = [requestString dataUsingEncoding:self.encoding allowLossyConversion:YES];
	[request setHTTPBody:requestData];
    
    //    [galleryConnection initWithRequest:request andDelegate:self];
    //    [galleryConnection start];
    
    data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    [self parseSynchronousRequest:data];
}


- (void)getApiKeyforUsername:(NSString *)username AndPassword:(NSString *)password;
{    
    if( [self beVerbose] ){ NSLog( @"getting API" ); }
    results = nil;
    //build the request
    NSURL *localURL = [[[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@/index.php/rest", self.url]] autorelease];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:localURL
                                    cachePolicy:NSURLRequestReloadIgnoringCacheData
                                    timeoutInterval:60.0];
	[request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"post"        forHTTPHeaderField:@"X-Gallery-Request-Method"];
	[request setHTTPMethod:@"POST"];

    NSString *requestString = [NSString stringWithFormat:@"user=%@&password=%@", username, password];
    NSData   *requestData   = [requestString dataUsingEncoding:self.encoding allowLossyConversion:YES];
	[request setHTTPBody:requestData];
    
//    [galleryConnection initWithRequest:request andDelegate:self];
//    [galleryConnection start];
    
    data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    [self parseSynchronousRequest:data];
}

- (void)getInfoForItem:(NSNumber *)restItem
{
    if( [self beVerbose] ){ NSLog( @"getting albums for item" ); }
    results = nil;
    NSURL *localURL = [[[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@/index.php/rest/item/%d", self.url, [restItem integerValue]]] autorelease];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:localURL
                                                        cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                        timeoutInterval:60.0];
	[request setValue:self.userAgent        forHTTPHeaderField:@"User-Agent"];
	[request setValue:self.galleryApiKey    forHTTPHeaderField:@"X-Gallery-Request-Key"];
	[request setValue:@"get"                forHTTPHeaderField:@"X-Gallery-Request-Method"];
	[request setHTTPMethod:@"POST"];
	
    NSData *requestData = [@"ouput=json&type=album" dataUsingEncoding:self.encoding allowLossyConversion:YES];
	[request setHTTPBody:requestData];
    
    data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    [self parseSynchronousRequest:data];
}

- (void)getInfoForItems:(NSArray *)urls
{
    if( [self beVerbose] ){ NSLog( @"getting items" ); }
    results = nil;
    
    NSURL *localURL = [[[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@/index.php/rest/items", self.url]] autorelease];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:localURL
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:60.0];
    [request setValue:self.userAgent        forHTTPHeaderField:@"User-Agent"];
    [request setValue:self.galleryApiKey    forHTTPHeaderField:@"X-Gallery-Request-Key"];
    [request setValue:@"get"                forHTTPHeaderField:@"X-Gallery-Request-Method"];
    [request setHTTPMethod:@"POST"];
	
    NSData *requestData = [ [NSString stringWithFormat:@"urls=[\"%@\"]",[urls componentsJoinedByString:@"\",\""]] dataUsingEncoding:self.encoding allowLossyConversion:YES];
    [request setHTTPBody:requestData];
    
    data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    [self parseSynchronousRequest:data];
}

- (void)createAlbumInEntity:(NSNumber *)restItem withParameters:(NSMutableDictionary *)parameters
{
    if( [self beVerbose] ){ NSLog( @"creating album" ); }
    results = nil;
    SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease ];
    
    // Required parameters
    //[parameters setObject:@"json"  forKey:@"name"];
    //[parameters setObject:@"album" forKey:@"title"];
    
     [parameters setObject:@"json"  forKey:@"output"];
     [parameters setObject:@"album" forKey:@"type"];
     
    NSURL *localURL = [[[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@/index.php/rest/item/%d", self.url, [restItem integerValue]]] autorelease];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:localURL
                                                        cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                        timeoutInterval:60.0];
	[request setValue:self.userAgent        forHTTPHeaderField:@"User-Agent"];
	[request setValue:self.galleryApiKey    forHTTPHeaderField:@"X-Gallery-Request-Key"];
	[request setValue:@"post"               forHTTPHeaderField:@"X-Gallery-Request-Method"];
	[request setHTTPMethod:@"POST"];
    
    NSString *requestString = [[NSString stringWithFormat:@"%@%@", @"entity=",[jsonWriter stringWithObject:parameters]] stringByAddingPercentEscapesUsingEncoding:self.encoding];
    NSData *requestData = [requestString dataUsingEncoding:self.encoding allowLossyConversion:YES];     
    [request setHTTPBody:requestData];
    
    data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    [self parseSynchronousRequest:data];

}

- (void)addPhotoAtPath:(NSString *)imagePath toEntity:(NSNumber *)restItem withParameters:(NSMutableDictionary *)parameters
{
    if( [self beVerbose] ){ NSLog( @"adding photo" ); }
    self.results = nil;

    SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease ];
    [parameters setObject:@"photo"                      forKey:@"type"];
    [parameters setObject:[imagePath lastPathComponent] forKey:@"name"];   

    NSMutableData *requestData = [[[NSMutableData alloc] init] autorelease]; 

    NSData   *imageData = [[[NSData alloc] initWithContentsOfFile:imagePath] autorelease];
    
    // Make a unique string for the boundary. Leveraged from Zach Wiley in iPhotoToGallery
    NSString *boundary = [NSString stringWithFormat:@"%@", [[NSProcessInfo processInfo] globallyUniqueString]];
    

    //build the request    
    NSURL *localURL = [[[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@/index.php/rest/item/%d", self.url, [restItem integerValue]]] autorelease];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:localURL
                                    cachePolicy:NSURLRequestReloadIgnoringCacheData
                                    timeoutInterval:60.0];
    [request setHTTPMethod:@"POST"];
	[request setValue:self.userAgent                                                                forHTTPHeaderField:@"User-Agent"];
	[request setValue:self.galleryApiKey                                                            forHTTPHeaderField:@"X-Gallery-Request-Key"];
	[request setValue:@"post"                                                                       forHTTPHeaderField:@"X-Gallery-Request-Method"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=\"%@\"", boundary] forHTTPHeaderField:@"Content-Type"];
	
    NSString *requestString = [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@",
                               @"--", boundary, @"\n",
                               @"Content-Disposition: form-data; name=\"entity\"\n",
                               @"Content-Type: text/plain; charset=UTF-8\n",
                               @"Content-Transfer-Encoding: 8bit\n",
                               @"\n",
                               [jsonWriter stringWithObject:parameters],@"\n",
                               @"--", boundary, @"\n",
                               @"Content-Disposition: form-data; name=\"file\"; filename=\"",[imagePath lastPathComponent],@"\"\n",
                               @"Content-Type: application/octet-stream\n",
                               @"Content-Transfer-Encoding: binary\n",
                               @"\n"];
                               
    if( [self beVerbose ] ){ NSLog( @"%@<data>\n--%@--", requestString, boundary ); }

    [requestData appendData:[requestString dataUsingEncoding:self.encoding allowLossyConversion:YES]];
    [requestData appendData:imageData];
    [requestData appendData:[[NSString stringWithFormat:@"\n--%@--\n", boundary ] dataUsingEncoding:self.encoding]];    
    
	[request setHTTPBody:requestData];
    
    [galleryConnection initWithRequest:request andDelegate:self];
    [galleryConnection start];
}

- (void)addPhotosAtPath:(NSString *)imagePath toUrl:(NSString *)restUrl
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    [fileManager fileExistsAtPath:imagePath isDirectory:&isDirectory];
    if (isDirectory) // If a folder already exists, empty it.
    {
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:imagePath error:nil];
        int i;
        for (i = 0; i < [contents count]; i++)
        {
            NSString *tempFilePath = [NSString stringWithFormat:@"%@%@", imagePath, [contents objectAtIndex:i]];
            AddPhotoQueueItem *item = [[AddPhotoQueueItem alloc] initWithUrl:restUrl andPath:tempFilePath 
                                                               andParameters:[NSMutableDictionary 
                                                                              dictionaryWithObjects:[NSArray arrayWithObjects:[tempFilePath lastPathComponent], @"", nil] 
                                                                              forKeys:[NSArray arrayWithObjects:@"title", @"description", nil ]]];
            [addPhotoQueue addObject:item];
            [item release];
        }
        
        [self processAddPhotoQueue];
    }
}

- (void) processAddPhotoQueue
{
    if( [[NSNumber numberWithInteger:[addPhotoQueue count]] isGreaterThan:[NSNumber numberWithInteger:0]] )
    {
        AddPhotoQueueItem *currentItem = [[[addPhotoQueue objectAtIndex:0] retain] autorelease];
        [addPhotoQueue removeObjectAtIndex:0];
        [self addPhotoAtPath:currentItem.path toUrl:currentItem.url withParameters:currentItem.parameters];
    }
}

- (void)addPhotoAtPath:(NSString *)imagePath toUrl:(NSString *)restUrl withParameters:(NSMutableDictionary *)parameters
{
    if( [self beVerbose] ){ NSLog( @"adding photo" ); }
    self.results = nil;
    
    SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease ];
    [parameters setObject:@"photo"                      forKey:@"type"];
    [parameters setObject:[imagePath lastPathComponent] forKey:@"name"];   
    
    NSMutableData *requestData = [[[NSMutableData alloc] init] autorelease]; 
    
    NSData   *imageData = [[[NSData alloc] initWithContentsOfFile:imagePath] autorelease];
    
    // Make a unique string for the boundary. Leveraged from Zach Wiley in iPhotoToGallery
    NSString *boundary = [NSString stringWithFormat:@"%@", [[NSProcessInfo processInfo] globallyUniqueString]];
    
    
    //build the request    
    NSURL *localURL = [[[NSURL alloc] initWithString:restUrl] autorelease];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:localURL
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:60.0];
    [request setHTTPMethod:@"POST"];
	[request setValue:self.userAgent                                                                forHTTPHeaderField:@"User-Agent"];
	[request setValue:self.galleryApiKey                                                            forHTTPHeaderField:@"X-Gallery-Request-Key"];
	[request setValue:@"post"                                                                       forHTTPHeaderField:@"X-Gallery-Request-Method"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=\"%@\"", boundary] forHTTPHeaderField:@"Content-Type"];
	
    NSString *requestString = [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@",
                               @"--", boundary, @"\n",
                               @"Content-Disposition: form-data; name=\"entity\"\n",
                               @"Content-Type: text/plain; charset=UTF-8\n",
                               @"Content-Transfer-Encoding: 8bit\n",
                               @"\n",
                               [jsonWriter stringWithObject:parameters],@"\n",
                               @"--", boundary, @"\n",
                               @"Content-Disposition: form-data; name=\"file\"; filename=\"",[imagePath lastPathComponent],@"\"\n",
                               @"Content-Type: application/octet-stream\n",
                               @"Content-Transfer-Encoding: binary\n",
                               @"\n"];
    
    if( [self beVerbose ] ){ NSLog( @"%@<data>\n--%@--", requestString, boundary ); }
    
    [requestData appendData:[requestString dataUsingEncoding:self.encoding allowLossyConversion:YES]];
    [requestData appendData:imageData];
    [requestData appendData:[[NSString stringWithFormat:@"\n--%@--\n", boundary ] dataUsingEncoding:self.encoding]];    
    
	[request setHTTPBody:requestData];
    
    [galleryConnection initWithRequest:request andDelegate:self];
    [galleryConnection start];
}


-(void)parseSynchronousRequest:(NSData *)myData
{
    // Get UTF8 String as a NSString from NSData response
    NSString *galleryResponseString = [[[NSString alloc] initWithData:myData encoding:NSUTF8StringEncoding] autorelease];
    NSMutableDictionary *newResults = [NSMutableDictionary new];
    
    // Testing is received string is a json object. i.e. bounded by {}
    if( [galleryResponseString length] >= 1 )
    {
        //      char startChar = [galleryResponseString characterAtIndex:0];
        //      char endChar   = [galleryResponseString characterAtIndex:( [galleryResponseString length]-1)];
        //      if( startChar == '{' && endChar == '}' ) -> just saving a few bits of memory.  
        if( [galleryResponseString characterAtIndex:0] == '{' && [galleryResponseString characterAtIndex:( [galleryResponseString length]-1)] == '}' )
        {
            SBJsonParser *parser = [[SBJsonParser alloc] init];
            
            [newResults addEntriesFromDictionary:[parser objectWithString:galleryResponseString error:nil]];             
            [newResults setValue:@"JSON" forKey:@"RESPONSE_TYPE"];
            
            [parser release];
            parser = nil;
        }
        else if( [galleryResponseString characterAtIndex:0] == '[' && [galleryResponseString characterAtIndex:( [galleryResponseString length]-1)] == ']' )
        {
            SBJsonParser *parser = [[SBJsonParser alloc] init];
            
            [newResults setValue:[parser objectWithString:galleryResponseString error:nil] forKey:@"RESULTS"];             
            [newResults setValue:@"JSON" forKey:@"RESPONSE_TYPE"];
            
            [parser release];
            parser = nil;
        }
        else if( [galleryResponseString characterAtIndex:0] == '"' && [galleryResponseString characterAtIndex:( [galleryResponseString length]-1)] == '"' )
        {
            [newResults setValue:[galleryResponseString stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]] forKey:@"GALLERY_RESPONSE"];
            [newResults setValue:@"TEXT" forKey:@"RESPONSE_TYPE"];
            
        }   
        else
        {
            [newResults setValue:galleryResponseString forKey:@"GALLERY_RESPONSE"];
            [newResults setValue:@"TEXT" forKey:@"RESPONSE_TYPE"];
        }
    }
    else
    {
        [newResults setValue:galleryResponseString forKey:@"GALLERY_RESPONSE"];
        [newResults setValue:@"TEXT" forKey:@"RESPONSE_TYPE"];
        
    }
    
    [newResults setValue:error forKey:@"ERROR"];
    
    self.results = newResults;
}

@end
