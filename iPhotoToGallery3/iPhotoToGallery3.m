//
//  iPhotoToGallery3.m
//  ApertureToGallery3
//
//  Created by Scott Selberg on 5/19/11.

/*
 Copyright (C) 2013 Scott Selberg
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 */

#import "iPhotoToGallery3.h"

@implementation iPhotoToGallery3
@synthesize gallery;
@synthesize galleryDirectory;
@synthesize rootGalleryAlbum;
@synthesize galleryApiKey;
@synthesize currentItem;
@synthesize waterMarkImageName;

- (id)initWithExportImageObj:(id <ExportImageProtocol>)obj
{
	if((self = [super init]))
	{
		_exportManager = obj;
		_progress.message = nil;
		_progressLock = [[NSLock alloc] init];
        
        cancel = NO;
        addPhotoQueue    = [[NSMutableArray alloc] init];
        retryPhotoQueue  = [[NSMutableArray alloc] init];
        donePhotoQueue   = [[NSMutableArray alloc] init];
        errorPhotoQueue  = [[NSMutableArray alloc] init];
        uploadRetries    = [NSNumber numberWithInt:2];

        self.gallery  = [[RestfulGallery alloc] init]; 
        self.gallery.delegate = self;
        //self.gallery.bVerbose = true;
        userDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];
        if( userDefaults ){
            preferences = [userDefaults mutableCopy];
            if( [preferences objectForKey:@"GALLERY_DIRECTORY"] ){
                self.galleryDirectory =  [[NSKeyedUnarchiver unarchiveObjectWithData:[preferences objectForKey:@"GALLERY_DIRECTORY"]] mutableCopy];                
            } else {
                self.galleryDirectory = [NSMutableArray arrayWithCapacity:0];
            }
            
            if( [preferences objectForKey:@"SELECTED_GALLERY_INDEX"] ){
                selectedGalleryIndex = [preferences objectForKey:@"SELECTED_GALLERY_INDEX"];
            } else {
                selectedGalleryIndex = [NSNumber numberWithInteger:0];                
            }
        } else {
            preferences = [[NSMutableDictionary alloc] init];
            self.galleryDirectory = [NSMutableArray arrayWithCapacity:0];
            selectedGalleryIndex = [NSNumber numberWithInteger:0];
        }
        
        //Stuff for the export
        // Create our temporary directory
//		tempDirectoryPath = [[NSString stringWithFormat:@"%@/Gallery3Export/", NSTemporaryDirectory()] retain];
        tempDirectoryPath = [[NSString stringWithFormat:@"/Users/scott/Desktop/iPhotoExport"]retain];
		
		// If it doesn't exist, create it
		NSFileManager *fileManager = [NSFileManager defaultManager];
		BOOL isDirectory;
		if (![fileManager fileExistsAtPath:tempDirectoryPath isDirectory:&isDirectory])
		{
            [fileManager createDirectoryAtPath:tempDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
		}
		else if (isDirectory) // If a folder already exists, empty it.
		{
            NSArray *contents = [fileManager contentsOfDirectoryAtPath:tempDirectoryPath error:nil];
			int i;
			for (i = 0; i < [contents count]; i++)
			{
				NSString *tempFilePath = [NSString stringWithFormat:@"%@%@", tempDirectoryPath, [contents objectAtIndex:i]];
                [fileManager removeItemAtPath:tempFilePath error:nil];
			}
		}
		else // Delete the old file and create a new directory
		{
            [fileManager removeItemAtPath:tempDirectoryPath error:nil];
            [fileManager createDirectoryAtPath:tempDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
		}
	}
	return self;
}

- (void)awakeFromNib
{
    if( [galleryDirectory count] > 0 )
    {
        [galleryDirectoryController setSelectionIndex:[selectedGalleryIndex integerValue]];
        selectedGallery            = [[galleryDirectoryController selectedObjects] objectAtIndex:0];
        self.gallery.galleryApiKey = selectedGallery.key;
        self.gallery.url           = selectedGallery.url;
        self.gallery.bGalleryValid = false;
    }
    
    if( [preferences valueForKey:@"SELECTED_WATERMARK_MODE"] )
    {
        [watermarkMenu selectItemAtIndex:[[preferences valueForKey:@"SELECTED_WATERMARK_MODE"] integerValue]];
        if( [[preferences valueForKey:@"SELECTED_WATERMARK_MODE"] intValue] == 0 )
        {
            [self enableWatermark:NO];
        }
    } else {
        [watermarkMenu selectItemAtIndex:0];                
        [self enableWatermark:NO];
    }
    
    if( [preferences valueForKey:@"SELECTED_WATERMARK_IMAGE"] )
    {
        [waterMarkImageNameTextField setStringValue:[preferences valueForKey:@"SELECTED_WATERMARK_IMAGE"]];
        self.waterMarkImageName = [preferences valueForKey:@"SELECTED_WATERMARK_IMAGE"];
    }
    
    [kindPopupButton selectItemAtIndex:3];
    [sizePopupButton selectItemAtIndex:5];
    [namePopupButton selectItemAtIndex:0];
    
    Version *versionTracker = [[[Version alloc] init] autorelease];
    [versionLabel setStringValue:[NSString stringWithFormat:@"Version %03.1f-%03.1f", 
                                  [versionTracker.iPhotoToGalleryVersion doubleValue], 
                                  [versionTracker.RestfulGalleryVersion doubleValue] ] ];

}

- (void)dealloc
{
    self.gallery                  = nil;
    self.rootGalleryAlbum         = nil;
    self.galleryApiKey            = nil;
    self.galleryDirectory         = nil;
    self.currentItem              = nil;
    self.waterMarkImageName       = nil;
    [addPhotoQueue release];
    [retryPhotoQueue release];
    [donePhotoQueue release];
    [errorPhotoQueue release];
    
    [preferences release];
    preferences = nil;
    
    // Clean up the temporary files
    [[NSFileManager defaultManager] removeItemAtPath:tempDirectoryPath error:nil];
	[tempDirectoryPath release];

	[_progressLock release];
	[_progress.message release];
	
	[super dealloc];
}


// protocol implementation
- (NSView <ExportPluginBoxProtocol> *)settingsView{	return settingsBox;}
- (NSView *)firstView{ return firstView;}

- (NSString *)requiredFileType
{
	if([_exportManager imageCount] > 1)
		return @"";
	else
		return @"jpg";
}

- (NSString *)defaultFileName
{
	if([_exportManager imageCount] > 1)
		return @"";
	else
		return @"sfe-0";
}

- (NSString*)getDestinationPath{ return @""; }
- (NSString *)defaultDirectory{	return @"~/Pictures/"; }
- (NSString *)name{return @"iPhotoToGallery3";}

- (ExportPluginProgress *)progress{	return &_progress;}
- (void)lockProgress{[_progressLock lock];}
- (void)unlockProgress{[_progressLock unlock];}
- (void)viewWillBeActivated{}
- (void)viewWillBeDeactivated{}

- (BOOL)wantsDestinationPrompt{	                 return NO; }
- (BOOL)treatSingleSelectionDifferently{         return NO; }
- (BOOL)handlesMovieFiles{                       return NO;  }
- (BOOL)validateUserCreatedPath:(NSString*)path{ return NO;  }

- (void)clickExport{cancel=NO;[_exportManager clickExport];}
- (void)startExport:(NSString *)path{cancel=NO;[_exportManager startExport];}
- (void)cancelExport{
    cancel = YES;
    
    for( int i = 0; i < [addPhotoQueue count]; i++ ){
        [errorPhotoQueue removeObjectAtIndex:i];
    }
    
    for( int i = 0; i < [retryPhotoQueue count]; i++ ){
        [donePhotoQueue removeObjectAtIndex:i];
    }

    for( int i = 0; i < [donePhotoQueue count]; i++ ){
        [donePhotoQueue removeObjectAtIndex:i];
    }

    for( int i = 0; i < [donePhotoQueue count]; i++ ){
        [donePhotoQueue removeObjectAtIndex:i];
    }
    
    
    
    [self.gallery cancel];
}
- (void)performExport:(NSString *)path
{    
    NSSize originalSize;
    NSString *exportName;
    BOOL addWatermark = NO;
    
    if( gallery.bGalleryValid )
    {
        cancel = false;
        [self lockProgress];
        _progress.shouldStop = NO;
        _progress.totalItems  = [_exportManager imageCount];
        _progress.indeterminateProgress = NO;
        _progress.currentItem = 0;
        [_progress.message autorelease];
        _progress.message = [[NSString stringWithFormat:@"Step 1 of 2: Preparing Images..."] retain];
        [self unlockProgress];
 
        GalleryAlbum *selectedAlbum;
        selectedAlbum = (GalleryAlbum *)[browser itemAtIndexPath:[browser selectionIndexPath]];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if( [watermarkMenu indexOfSelectedItem] > 0 && [fileManager fileExistsAtPath:self.waterMarkImageName] )
        {
            addWatermark = YES;
        }        
        
        ImageExportOptions imageOptions;
        switch( [kindPopupButton indexOfSelectedItem ] )
        {
            case 0: imageOptions.format = kUTTypeJPEG; imageOptions.quality = EQualityLow;  break;
            case 1: imageOptions.format = kUTTypeJPEG; imageOptions.quality = EQualityMed;  break;
            case 2: imageOptions.format = kUTTypeJPEG; imageOptions.quality = EQualityHigh; break;
            case 3: imageOptions.format = kUTTypeJPEG; imageOptions.quality = EQualityMax;  break;
            default: imageOptions.format = kUTTypeJPEG; break;
        }

        if( [includeMetaData state] == NSOnState )
        {
            imageOptions.metadata = EMBoth;
        }

        for (int imageNum = 0; imageNum < (int)[_exportManager imageCount] && !cancel; imageNum++){
            
            NSString     *imagePath     = [_exportManager imagePathAtIndex:imageNum];
            NSString     *newPath       = [tempDirectoryPath stringByAppendingPathComponent:[imagePath lastPathComponent]];
             

            switch( [sizePopupButton indexOfSelectedItem] )
            {
                case 0: imageOptions.width = 320;  imageOptions.height = 320;  break;
                case 1: imageOptions.width = 640;  imageOptions.height = 640;  break;
                case 2: imageOptions.width = 1280; imageOptions.height = 1280; break;
                case 3: 
                    originalSize = [_exportManager imageSizeAtIndex:imageNum];
                    imageOptions.width  = (int)( ((double)originalSize.width )/4.0 );
                    imageOptions.height = (int)( ((double)originalSize.height)/4.0 );
                    break;
                case 4: 
                    originalSize = [_exportManager imageSizeAtIndex:imageNum];
                    imageOptions.width  = (int)( ((double)originalSize.width )/2.0 );
                    imageOptions.height = (int)( ((double)originalSize.height)/2.0 );
                    break;
                case 5: break;
                case 7: imageOptions.width = [maxWidth intValue]; imageOptions.height = [maxHeight intValue]; break;
                default: break;
            }

            switch( [namePopupButton indexOfSelectedItem] )
            {
                case 0: exportName = [_exportManager imageTitleAtIndex:imageNum]; break;
                case 1: exportName = [imagePath lastPathComponent];               break;
                case 3: exportName = [NSString stringWithFormat:@"%@.%03d", [sequentialPrefix stringValue], imageNum]; break;
                default: exportName = [_exportManager imageTitleAtIndex:imageNum]; break;
            }
            
            //NSDictionary *imageExifDict = [_exportManager imageExifPropertiesAtIndex:imageNum];
            //NSArray      *imageKeywords = [_exportManager imageKeywordsAtIndex:imageNum];
            //int          imageRating    = [_exportManager imageRatingAtIndex:imageNum];

            [_exportManager exportImageAtIndex:imageNum dest:newPath options:&imageOptions];
            
            if( addWatermark )
            {
                [self.gallery waterMarkImage:newPath with:self.waterMarkImageName andTransformIndex:[watermarkMenu indexOfSelectedItem]];                
            }
            
            AddPhotoQueueItem *item = [[AddPhotoQueueItem alloc] initWithUrl:selectedAlbum.url 
                                                                 andPath:newPath 
                                                                 andParameters:[NSMutableDictionary 
                                                                                dictionaryWithObjects:[NSArray arrayWithObjects:
                                                                                                       exportName,
                                                                                                       [_exportManager imageCommentsAtIndex:imageNum], nil] 
                                                                                forKeys:[NSArray arrayWithObjects:@"title", @"description", nil ]]];
            [addPhotoQueue addObject:item];
            [item release];
            
            [self lockProgress];
            _progress.currentItem = (imageNum + 1);
            [self unlockProgress];
        }
        
        [NSThread detachNewThreadSelector:@selector(startExportInNewThread) toTarget:self withObject:nil];
    }
}

// this is necessary as the NSURLConnection does not work well except in NSDefaultRunLoopMode - which is not the modal panel run mode.
-(void)startExportInNewThread
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [self processAddPhotoQueue];
    running = YES;
    while(running) {
        if( ![[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:100000]] )
        {
            break;
        }
    }    
    [pool release];    
}

- (void)savePreferences {
    [preferences setObject:[NSKeyedArchiver archivedDataWithRootObject:galleryDirectory] forKey:@"GALLERY_DIRECTORY"];    
    [preferences setObject:selectedGalleryIndex forKey:@"SELECTED_GALLERY_INDEX"];
    [preferences setObject:[NSNumber numberWithInteger:[watermarkMenu indexOfSelectedItem]] forKey:@"SELECTED_WATERMARK_MODE"];
    [preferences setObject:[waterMarkImageNameTextField stringValue] forKey:@"SELECTED_WATERMARK_IMAGE"];
    
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:preferences forName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];
}

- (IBAction)selectWatermarkImage:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setTreatsFilePackagesAsDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel beginSheetModalForWindow:[_exportManager window] completionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            [openPanel orderOut:self]; // close panel before we might present an error
            self.waterMarkImageName = [[openPanel URL] path];
            [waterMarkImageNameTextField setStringValue:self.waterMarkImageName];
            [self savePreferences];
        }
    }];        
}

-(IBAction)selectNoWatermark:(id)sender{[self enableWatermark:NO];}
-(IBAction)selectScaledWatermark:(id)sender{[self enableWatermark:YES];}
-(IBAction)selectTopLeftWatermark:(id)sender{[self enableWatermark:YES];}
-(IBAction)selectTopCenterWatermark:(id)sender{[self enableWatermark:YES];}
-(IBAction)selectTopRightWatermark:(id)sender{[self enableWatermark:YES];}
-(IBAction)selectMiddleLeftWatermark:(id)sender{[self enableWatermark:YES];}
-(IBAction)selectMiddleCenterWatermark:(id)sender{[self enableWatermark:YES];}
-(IBAction)selectMiddleRightWatermark:(id)sender{[self enableWatermark:YES];}
-(IBAction)selectBottomLeftWatermark:(id)sender{[self enableWatermark:YES];}
-(IBAction)selectBottomCenterWatermark:(id)sender{[self enableWatermark:YES];}
-(IBAction)selectBottomRightWatermark:(id)sender{[self enableWatermark:YES];}

-(void)enableWatermark:(BOOL)bEnable
{
    [waterMarkImageNameTextField setEnabled:bEnable];
    [browseForWaterMarkButton    setEnabled:bEnable];
    [self savePreferences];
}

/************************************************************
 Interact with Gallery
 ************************************************************/
- (IBAction) getApiKey:(id)sender
{
    GalleryInfo *galleryInfo = [[galleryDirectoryController selectedObjects] objectAtIndex:0];
    [gallery getApiKeyforGallery:galleryInfo.url AndUsername:galleryInfo.username AndPassword:[newGalleryPassword stringValue]];
    galleryInfo.key = [gallery.results objectForKey:@"GALLERY_RESPONSE"];
}
- (IBAction)makeAlbum:(id)sender
{
    NSNumber *localEntityId;
    NSNumber *newColumn;
    NSString *newAlbumUrl;
    NSArray  *albumChildren;
    GalleryAlbum *selectedAlbum;
    
    selectedAlbum = (GalleryAlbum *)[browser itemAtIndexPath:[browser selectionIndexPath]];
    
    if( selectedAlbum == nil ){
        [browser selectRow:0 inColumn:0];
        selectedAlbum = (GalleryAlbum *)[browser itemAtIndexPath:[browser selectionIndexPath]];
    }
    
    localEntityId = [selectedAlbum entityId];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:4];
    [parameters setObject:[albumName  stringValue] forKey:@"name"];
    [parameters setObject:[albumTitle stringValue] forKey:@"title"];
    
    [gallery createAlbumInEntity:localEntityId withParameters:parameters];
    newAlbumUrl= [[gallery results] objectForKey:@"url"];
    
    selectedAlbum.dataIsStale      = true;
    selectedAlbum.childrenAreStale = true;        
    newColumn = [NSNumber numberWithInteger:([browser selectedColumn]+1)];
    albumChildren = [selectedAlbum children];
    
    for (NSInteger col = [browser lastColumn]; col >= 0; col--) {
        [browser reloadColumn:col];
    }
    
    if( [browser lastColumn] < [newColumn integerValue] )
    {
        [browser addColumn];
        [browser scrollColumnsLeftBy:1];
    }
    
    for( int i = 0; i < [albumChildren count]; i++ )
    {
        GalleryAlbum *album = (GalleryAlbum *)[browser itemAtRow:i inColumn:[newColumn integerValue]];
        if( [newAlbumUrl isEqualToString:[album url]] )
        {
            [browser selectRow:i inColumn:[newColumn integerValue]];
            continue;
        }
    }
    
    // clear the text fields
    [albumName  setStringValue:@""];
    [albumTitle setStringValue:@""];
    
    [addAlbumWindow orderOut:nil];
    [NSApp endSheet:addAlbumWindow];     
}

- (void) processAddPhotoQueue
{
    if( !cancel )
    {
        if( [[NSNumber numberWithInteger:[retryPhotoQueue count]] isGreaterThan:[NSNumber numberWithInteger:0]] )
        {
            [self lockProgress];
            _progress.currentItem = 0;
            _progress.totalItems = 100*( [addPhotoQueue count] + [retryPhotoQueue count] + [donePhotoQueue count] + [errorPhotoQueue count] );
            [_progress.message autorelease];
            _progress.message = [[NSString stringWithFormat:@"Step 2 of 2: Uploading Image %d of %d (retry %d)", 
                                       [donePhotoQueue count] + [errorPhotoQueue count] + 1, 
                                       [addPhotoQueue count]  + [retryPhotoQueue count] 
                                       + [donePhotoQueue count] + [errorPhotoQueue count],
                                       + [currentItem.uploadAttempts intValue] ] retain];
            [self unlockProgress];
            
            self.currentItem = [retryPhotoQueue objectAtIndex:0];
            [retryPhotoQueue removeObjectAtIndex:0];
            [gallery addPhotoAtPath:currentItem.path toUrl:currentItem.url withParameters:currentItem.parameters];
        }
        else if( [[NSNumber numberWithInteger:[addPhotoQueue count]] isGreaterThan:[NSNumber numberWithInteger:0]] )
        {
            [self lockProgress];
            _progress.currentItem = 0;
            _progress.totalItems = 100*( [addPhotoQueue count] + [retryPhotoQueue count] + [donePhotoQueue count] + [errorPhotoQueue count] );
            [_progress.message autorelease];
            _progress.message = [[NSString stringWithFormat:@"Step 2 of 2: Uploading Image %d of %d", 
                                       [donePhotoQueue count] + [errorPhotoQueue count] + 1, 
                                       [addPhotoQueue count]  + [retryPhotoQueue count] 
                                       + [donePhotoQueue count] + [errorPhotoQueue count]] retain];
            [self unlockProgress];
            
            self.currentItem = [addPhotoQueue objectAtIndex:0];
            [addPhotoQueue removeObjectAtIndex:0];
            [gallery addPhotoAtPath:currentItem.path toUrl:self.currentItem.url withParameters:currentItem.parameters];
        }
        else
        {
            [self performSelectorOnMainThread:@selector(done) withObject:nil waitUntilDone:YES];
            running = NO;
        }
    }
}
-(void)done
{
    AddPhotoQueueItem* info;
    NSMutableArray* errorNames = [NSMutableArray arrayWithCapacity:[errorPhotoQueue count]];

    if( [showGalleryOnCompletion state] == NSOnState )
    {
        GalleryAlbum *selectedAlbum;
        selectedAlbum = (GalleryAlbum *)[browser itemAtIndexPath:[browser selectionIndexPath]];

        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[selectedAlbum webUrl]]];
    }
    
    if( [errorPhotoQueue count] > 0 )
    {
        NSEnumerator* enumerator = [errorPhotoQueue objectEnumerator];
        while ((info = [enumerator nextObject])) {
            [errorNames addObject:[info.path lastPathComponent]];
        }
        
        NSString* errorMessage     = [NSString stringWithFormat:@"Failed to upload %d images:", [errorPhotoQueue count]];
        NSString* errorDescription = [NSString stringWithFormat:[errorNames componentsJoinedByString:@"\n"]];
        NSAlert* alert = [NSAlert alertWithMessageText:errorMessage  
                                         defaultButton:nil 
                                       alternateButton:nil 
                                           otherButton:nil
                             informativeTextWithFormat:errorDescription];
        [alert runModal];
    }

    for( int i = 0; i < [addPhotoQueue count]; i++ ){
        [errorPhotoQueue removeObjectAtIndex:i];
    }
    
    for( int i = 0; i < [retryPhotoQueue count]; i++ ){
        [donePhotoQueue removeObjectAtIndex:i];
    }

    for( int i = 0; i < [errorPhotoQueue count]; i++ ){
        [errorPhotoQueue removeObjectAtIndex:i];
    }

    for( int i = 0; i < [donePhotoQueue count]; i++ ){
        [donePhotoQueue removeObjectAtIndex:i];
    }

    [self lockProgress];
    [_progress.message autorelease];
    _progress.message = nil;
    _progress.shouldStop = YES;
    [self unlockProgress];
    
}
- (void)got:(NSMutableDictionary *)myResults;
{
    if( [[myResults valueForKey:@"HAS_ERROR"] boolValue] )
    {
        if( ( [currentItem.uploadAttempts intValue] ) >= [uploadRetries intValue] )
        {
            [errorPhotoQueue addObject:currentItem];
        } 
        else
        {
            currentItem.uploadAttempts = [NSNumber numberWithInt:[currentItem.uploadAttempts intValue] + 1 ];
            [retryPhotoQueue addObject:currentItem];
        }
    }
    else
    {
        [donePhotoQueue addObject:currentItem];
    }
    
    [self processAddPhotoQueue];
}

- (void) updateTotalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    [self lockProgress];
    _progress.currentItem = 100.0*((double)[errorPhotoQueue count] + (double)[donePhotoQueue count] + ((double)totalBytesWritten)/((double)totalBytesExpectedToWrite));
	[self unlockProgress];
}

/************************************************************
 Click to go places
 ************************************************************/

- (IBAction)clickDonate:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=PZ4RFJFTEMED2"]];
}

- (IBAction)clickGoGitHub:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://saselberg.github.com/ApertureToGallery3"]];
}
/************************************************************
  Manage window sheets
 ************************************************************/
-(IBAction)showManageGalleries:(id)sender
{
    [NSApp beginSheet:manageGalleriesWindow modalForWindow:[_exportManager window] modalDelegate:self didEndSelector:NULL contextInfo:nil];    
}
-(IBAction)hideManageGalleries:(id)sender
{
    selectedGallery = [[galleryDirectoryController selectedObjects] objectAtIndex:0];
    self.gallery.galleryApiKey = selectedGallery.key;
    self.gallery.url           = selectedGallery.url;
    self.gallery.bGalleryValid = false;
    
    if( ![selectedGalleryIndex isEqualToNumber:[NSNumber numberWithInteger:[galleryDirectoryController selectionIndex]]] )
    {
        rootGalleryAlbum.dataIsStale      = true;
        rootGalleryAlbum.childrenAreStale = true;        
        
        for (NSInteger col = [browser lastColumn]; col >= 0; col--) {
            [browser reloadColumn:col];
        }
    }
    
    selectedGalleryIndex = [NSNumber numberWithInteger:[galleryDirectoryController selectionIndex]];
    [self savePreferences];
    
    [manageGalleriesWindow orderOut:nil];
    [NSApp endSheet:manageGalleriesWindow];     
}

-(IBAction)addGalleryInformation:(id)sender
{
    [galleryDirectoryController add:self];
    [NSApp beginSheet:galleryInformationWindow modalForWindow:manageGalleriesWindow modalDelegate:self didEndSelector:NULL contextInfo:nil];    
}
-(IBAction)showGalleryInformation:(id)sender
{
    [NSApp beginSheet:galleryInformationWindow modalForWindow:manageGalleriesWindow modalDelegate:self didEndSelector:NULL contextInfo:nil];    
}
-(IBAction)hideGalleryInformation:(id)sender
{
//    [newGalleryPassword setStringValue:@""];
    
    [galleryInformationWindow orderOut:nil];
    [NSApp endSheet:galleryInformationWindow];     
}

-(IBAction)showAddAlbum:(id)sender
{
    [NSApp beginSheet:addAlbumWindow modalForWindow:[_exportManager window] modalDelegate:self didEndSelector:NULL contextInfo:nil];    
}
-(IBAction)hideAddAlbum:(id)sender
{
    [addAlbumWindow orderOut:nil];
    [NSApp endSheet:addAlbumWindow];     
}

-(IBAction)showAbout:(id)sender
{
    [NSApp beginSheet:aboutWindow modalForWindow:[_exportManager window] modalDelegate:self didEndSelector:NULL contextInfo:nil];    
}
-(IBAction)hideAbout:(id)sender
{
    [aboutWindow orderOut:nil];
    [NSApp endSheet:aboutWindow];     
}

/************************************************************
   Methods to enable the browser
 ************************************************************/
- (id)rootItemForBrowser:(NSBrowser *)browser
{
#pragma unused (browser)
    //        NSLog( @"rootItemForBrowser" );
    if (rootGalleryAlbum == nil) {
        rootGalleryAlbum = [[GalleryAlbum alloc] initWithGallery:gallery andEntityId:[NSNumber numberWithInteger:0]];
    }
    return rootGalleryAlbum;    
}

- (NSInteger)browser:(NSBrowser *)browser numberOfChildrenOfItem:(id)item 
{
#pragma unused (browser)
    //        NSLog( @"browser:numberOfChidrenOfItem" );
    GalleryAlbum *album = (GalleryAlbum *)item;
    return [album numberOfChildren];
}

- (id)browser:(NSBrowser *)browser child:(NSInteger)index ofItem:(id)item {
#pragma unused (browser)
    //        NSLog( @"browser:child:index:ofItem" );
    GalleryAlbum *album = (GalleryAlbum *)item;
    return [album.children objectAtIndex:index];
}

- (BOOL)browser:(NSBrowser *)browser isLeafItem:(id)item {
#pragma unused (browser)
    //        NSLog( @"browser:isLeafItem" );
    GalleryAlbum *album = (GalleryAlbum *)item;
    return !album.hasChildren;
}

- (id)browser:(NSBrowser *)browser objectValueForItem:(id)item {
#pragma unused (browser)
    //        NSLog( @"objectValueForItem" );
    GalleryAlbum *album = (GalleryAlbum *)item;
    return album.displayName;
}

/************************************************************
 Methods to enable the browser
 ************************************************************/
-(IBAction)select320Size:(id)sender{[self enableCustomSizeSettings:NO];}
-(IBAction)select640Size:(id)sender{[self enableCustomSizeSettings:NO];}
-(IBAction)select1280Size:(id)sender{[self enableCustomSizeSettings:NO];}
-(IBAction)selectQuarterSize:(id)sender{[self enableCustomSizeSettings:NO];}
-(IBAction)selectHalfSize:(id)sender{[self enableCustomSizeSettings:NO];}
-(IBAction)selectFullSize:(id)sender{[self enableCustomSizeSettings:NO];}
-(IBAction)selectCustomSize:(id)sender{[self enableCustomSizeSettings:YES];}

-(void)enableCustomSizeSettings:(BOOL)bEnable
{
    [maxWidth setEnabled:bEnable];
    [maxHeight setEnabled:bEnable];    
}


-(IBAction)selectUseTitle:(id)sender{[self enableSequentialPrefix:NO];};
-(IBAction)selectUseFileName:(id)sender{[self enableSequentialPrefix:NO];};
-(IBAction)selectUseSequential:(id)sender{[self enableSequentialPrefix:YES];};

-(void)enableSequentialPrefix:(BOOL)bEnable
{
    [sequentialPrefix setEnabled:bEnable];
}


@end
