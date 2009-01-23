/**
 * MWSServer.m
 *
 * History:
 * bkennedy on 07/05/07 - Created.
 *
 * Copyright MIT 2007.  All rights reserved.
 */

#import "MWSServer.h"
#import "MonkeyWorksCocoa/MWCocoaEventFunctor.h"
#import <sys/types.h>
#import <sys/socket.h>
#import <ifaddrs.h>

#define DEFAULT_HOST_IP @"127.0.0.1"
#define LISTENING_ADDRESS_KEY @"listeningAddressKey"

@interface MWSServer(PrivateMethods)
- (void)processEvent:(id)cocoaEvent;
@end


@implementation MWSServer

- (id) init {
	self = [super init];
	if (self != nil) {
		core = boost::shared_ptr <Server>(new Server());
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		listeningAddress = [defaults objectForKey:LISTENING_ADDRESS_KEY];

//		// TODO: this is crazy slow on some machines/networks
//		#define ESCHEW_NSHOST	1
//		#if ESCHEW_NSHOST
//			// TODO: double check this
//			struct ifaddrs *addrs;
//			int i = getifaddrs(&addrs);
//			NSMutableArray *netAddresses = [[NSMutableArray alloc] init];
//			while(addrs != NULL){
//				[netAddresses insertObject:[NSString stringWithCString:addrs->ifa_name] atIndex:0];
//				addrs = addrs->ifa_next;
//			}
//		#else	
//			NSArray *netAddresses = [[NSHost currentHost] addresses];
//		#endif
//		
//		NSString *regex  = @"[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}";
//		NSString *predicateFormat = [[@"SELF MATCHES \"" stringByAppendingString:regex] stringByAppendingString:@"\""];
//		
//		NSPredicate *addressPredicate =
//			[NSPredicate predicateWithFormat:predicateFormat];
//		
//		NSArray *filteredArray = [netAddresses filteredArrayUsingPredicate:addressPredicate];
//				
//		if(listeningAddress == nil || ![filteredArray containsObject:listeningAddress]) { 
//			listeningAddress = [[NSString alloc] initWithString:DEFAULT_HOST_IP];
//		}
		
		cc = [[MWConsoleController alloc] init];
	}
	return self;
}



- (void)dealloc {
	[listeningAddress release];
	[cc release];
	[super dealloc];
}
/****************************************************************
 *              NSApplication Delegate Methods
 ***************************************************************/
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// initialize GUI items
	
	// make a core server
//	boost::shared_ptr <CocoaEventFunctor> cef = boost::shared_ptr <CocoaEventFunctor>(new CocoaEventFunctor(self,@selector(processEvent:), "MWSServer"));
//	core->registerCallback(cef);

	
	core->setListenLowPort(19989);
    core->setListenHighPort(19999);

	string hostname;
	if(listeningAddress == Nil || [listeningAddress isEqualToString:@""]){
		hostname = "127.0.0.1";
	} else {
		hostname = [listeningAddress cStringUsingEncoding:NSASCIIStringEncoding];
	}
	
	core->setHostname(hostname);
	
	[cc setTitle:@"Server Console"];
	[cc setDelegate:self];
	
	core->startServer();
	core->startAccepting();	
	[self updateGUI:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // stop any data files still open.

    // close all open network connections.
    
    // close any applications it owns.
	//delete core;
}

/****************************************************************
*              IBAction methods
***************************************************************/
- (IBAction)toggleConsole:(id)sender {
	if([[cc window] isVisible]) {
		[cc close];
	} else {
		[cc showWindow:nil];	
	}
}

- (IBAction)closeExperiment:(id)sender {
	core->closeExperiment();
}

- (IBAction)openExperiment:(id)sender {
    NSOpenPanel * op = [NSOpenPanel openPanel];
    [op setCanChooseDirectories:NO];
    // it is important that you never allow multiple files to be selected!
    [op setAllowsMultipleSelection:NO];

    int bp = [op runModalForTypes:[NSArray arrayWithObjects:@"xml", nil]];
    if(bp == NSOKButton) {
        NSArray * fn = [op filenames];
        NSEnumerator * fileEnum = [fn objectEnumerator];
        NSString * filename;
        while(filename = [fileEnum nextObject]) {
			if(!core->openExperiment([filename cStringUsingEncoding:NSASCIIStringEncoding])) {
                NSLog(@"Could not open experiment %@", filename);
            }
        }
    }
}

- (IBAction)saveVariables:(id)sender {
    NSSavePanel * save = [[NSSavePanel savePanel] retain];
    [save setAllowedFileTypes:[NSArray arrayWithObject:@"xml"]];
    [save setCanCreateDirectories:NO];
    if([save runModalForDirectory:nil file:nil] ==
	   NSFileHandlingPanelOKButton)  {
		core->saveVariables(boost::filesystem::path([[save filename] cStringUsingEncoding:NSASCIIStringEncoding], 
													boost::filesystem::native));
    }
	
	[save release];	
}

- (IBAction)loadVariables:(id)sender {
	NSOpenPanel * op = [[NSOpenPanel openPanel] retain];
    [op setCanChooseDirectories:NO];
    // it is important that you never allow multiple files to be selected!
    [op setAllowsMultipleSelection:NO];
	
    int bp = [op runModalForTypes:[NSArray arrayWithObjects:@"xml", nil]];
    if(bp == NSOKButton) {
        NSArray * fn = [op filenames];
        NSEnumerator * fileEnum = [fn objectEnumerator];
        NSString * filename;
        while(filename = [fileEnum nextObject]) {			
			core->loadVariables(boost::filesystem::path([filename cStringUsingEncoding:NSASCIIStringEncoding], 
														boost::filesystem::native));
        }
    }
	
	[op release];
}

- (IBAction)openDataFile:(id)sender {
    NSSavePanel * save = [[NSSavePanel savePanel] retain];
    [save setAllowedFileTypes:[NSArray arrayWithObject:@"mwk"]];
    [save setCanCreateDirectories:NO];
    if([save runModalForDirectory:nil file:nil] ==
	   NSFileHandlingPanelOKButton)  {
        core->openDataFile([[[save filename] lastPathComponent]
                            cStringUsingEncoding:NSASCIIStringEncoding]);
    }
	
	[save release];
}

- (IBAction)closeDataFile:(id)sender {
	core->closeFile();
}


- (IBAction)startExperiment:(id)delegate {
	if(!core->isExperimentRunning()) {
		core->startExperiment();
	}
	[self updateGUI:nil];
}

- (IBAction)stopExperiment:(id)delegate {
	if(core->isExperimentRunning()) {
		core->stopExperiment();
	}
	[self updateGUI:nil];
}



////////////////////////////////////////////////////////////////////////////////
// Delegate Methods
////////////////////////////////////////////////////////////////////////////////
- (NSNumber *)codeForTag:(NSString *)tag {
	return [NSNumber numberWithInt:core->getCode([tag cStringUsingEncoding:NSASCIIStringEncoding])];
}

- (void)startServer {
	core->startServer();
	[self setListeningAddress:listeningAddress];
	[self updateGUI:nil];
}

- (void)stopServer {
	core->stopServer();
	[self updateGUI:nil];
}

- (void)startAccepting {
	core->startAccepting();
	[self updateGUI:nil];
}

- (void)stopAccepting {
	core->stopAccepting();	
	[self updateGUI:nil];
}

- (NSNumber *)experimentLoaded {
	return [NSNumber numberWithBool:core->isExperimentLoaded()];
}

- (NSNumber *)experimentRunning {
	return [NSNumber numberWithBool:core->isExperimentRunning()];
}

- (NSNumber *)serverAccepting {
	return [NSNumber numberWithBool:core->isAccepting()];
}

- (NSNumber *)serverStarted {
	return [NSNumber numberWithBool:core->isStarted()];	
}

- (void)updateGUI:(id)arg {
	[mc updateDisplay];
	[tc updateDisplay];
}

- (void)unregisterCallbacksWithKey:(NSString *)key {
	core->unregisterCallbacks([key cStringUsingEncoding:NSASCIIStringEncoding]);
}

- (void)registerEventCallbackWithRecevier:(id)receiver 
							  andSelector:(SEL)selector
								   andKey:(NSString *)key { 
	boost::shared_ptr <CocoaEventFunctor> cef = boost::shared_ptr <CocoaEventFunctor>(new CocoaEventFunctor(receiver,
																											   selector, 
																											   [key cStringUsingEncoding:NSASCIIStringEncoding]));
	core->registerCallback(cef);
}

- (void)registerEventCallbackWithRecevier:(id)receiver 
							  andSelector:(SEL)selector
								   andKey:(NSString *)key
						  forVariableCode:(NSNumber *)_code {
	int code = [_code intValue];
	if(code >= 0) {
		boost::shared_ptr <CocoaEventFunctor> cef = boost::shared_ptr <CocoaEventFunctor>(new CocoaEventFunctor(receiver,
																												   selector, 
																												   [key cStringUsingEncoding:NSASCIIStringEncoding]));
		
		core->registerCallback(cef, code);
	}
	
}

- (void)openNetworkPreferences:(id)sender {
	[nc openAndInitWindow:sender];
}

- (NSString *)currentNetworkAddress:(id)sender {
	return listeningAddress;
}

- (NSString *)defaultNetworkAddress:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *defaultAddress = [defaults objectForKey:LISTENING_ADDRESS_KEY];
	
	if(defaultAddress == nil) { 
		defaultAddress = DEFAULT_HOST_IP;
	}
	
	return defaultAddress;
}

- (void)setListeningAddress:(NSString *)address {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:address forKey:LISTENING_ADDRESS_KEY];
	[defaults synchronize];
	
//	listeningAddress = address;
	
//	core->stopAccepting();
//	core->stopServer();
//	core->setHostname([listeningAddress cStringUsingEncoding:NSASCIIStringEncoding]);
//	core->startServer();
//	core->startAccepting();	
	[self updateGUI:nil];	
}

- (NSArray *)variableNames {
	std::vector<std::string> varTagNames(core->getVariableNames());
	NSMutableArray *varNames = [[[NSMutableArray alloc] init] autorelease];
	
	for(std::vector<std::string>::iterator iter = varTagNames.begin();
		iter != varTagNames.end(); 
		++iter) {
		[varNames addObject:[NSString stringWithCString:iter->c_str() 
											   encoding:NSASCIIStringEncoding]];
	}
	
	return varNames;	
}


////////////////////////////////////////////////////////////////////////////////
// Private Methods
////////////////////////////////////////////////////////////////////////////////
- (void)processEvent:(id)event {
}


@end