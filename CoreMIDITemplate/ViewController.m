//
//  ViewController.m
//  CoreMIDITemplate
//
//  Created by Maxime Bokobza on 8/1/13.
//  Copyright (c) 2013 Maxime Bokobza. All rights reserved.
//

#import "ViewController.h"

static void ReadCallBackProc(const MIDIPacketList *pktlist, void *refCon, void *srcConnRefCon);
static void InputPortCallback(const MIDIPacketList * pktlist, void * refCon, void * connRefCon);

@interface ViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;
@property (nonatomic, strong) IBOutlet UILabel *noteLabel;
@property (nonatomic) uint note;

- (IBAction)switchValueChanged:(id)sender;
- (IBAction)buttonPressed;
- (IBAction)buttonReleased;
- (IBAction)sliderValueChanged;

- (void)sendNote:(uint)note on:(BOOL)on;

@end


@implementation ViewController

- (IBAction)switchValueChanged:(id)sender
{
    if ([sender isOn])
	{
		NSString *clientName = @"CoreMIDITemplate MIDI Client";
        MIDIClientCreate((__bridge CFStringRef)clientName, NULL, NULL, &client);
		MIDIObjectSetIntegerProperty(client, kMIDIPropertyUniqueID, clientName);
        MIDIOutputPortCreate(client, (CFStringRef)@"CoreMIDITemplate Output Port", &outputPort);
        MIDIInputPortCreate(client, (CFStringRef)@"CoreMIDITemplate Input Port", ReadCallBackProc,
							(__bridge void*)self, &inputPort);
		NSString *destPortName = @"BLE Destintation Port";
		SInt32 destUniqueId = destPortName.hash;
		
		MIDIDestinationCreate(client, (__bridge CFStringRef)destPortName, InputPortCallback,
							  (__bridge void*)self, &virtualDestinationEndpoint);
		MIDIObjectSetIntegerProperty(virtualDestinationEndpoint, kMIDIPropertyUniqueID, destUniqueId + 1);
		
		NSString *srcPortName = @"BLE Source Port";
		SInt32 srcUniqueId = srcPortName.hash;
		MIDISourceCreate(client, (__bridge CFStringRef)srcPortName, &virtualSourceEndpoint);
		MIDIObjectSetIntegerProperty(virtualSourceEndpoint, kMIDIPropertyUniqueID, srcUniqueId + 2);
	}
	else
	{
        [self midiDispose];
	}
}

- (void) dealloc
{
	[self midiDispose];
}

- (void) midiDispose
{
    if (outputPort)
		MIDIPortDispose(outputPort);
	
    if (inputPort)
		MIDIPortDispose(inputPort);
	
    if (virtualSourceEndpoint)
		MIDIEndpointDispose(virtualSourceEndpoint);
	
	if (virtualDestinationEndpoint)
		MIDIEndpointDispose(virtualDestinationEndpoint);
	
    if (client)
        MIDIClientDispose(client);
}

- (IBAction)buttonPressed
{
    self.note = (uint)self.slider.value;
    [self sendNote:self.note on:YES];
}

- (IBAction)buttonReleased
{
    [self sendNote:self.note on:NO];
}

- (void)sendNote:(uint)note on:(BOOL)on
{
    // http://www.onicos.com/staff/iz/formats/midi-event.html
    const UInt8 data[]  = { on ? 0x90 : 0x80, note, 127 };
    ByteCount size = sizeof(data);
    
    Byte packetBuffer[sizeof(MIDIPacketList)];
    MIDIPacketList *packetList = (MIDIPacketList *)packetBuffer;
    
    MIDIPacketListAdd(packetList,
                      sizeof(packetBuffer),
                      MIDIPacketListInit(packetList),
                      0,
                      size,
                      data);
    
    for (ItemCount index = 0; index < MIDIGetNumberOfDestinations(); index++)
	{
        MIDIEndpointRef outputEndpoint = MIDIGetDestination(index);
        if (outputEndpoint)
            MIDISend(outputPort, outputEndpoint, packetList);
    }
}

- (void)sliderValueChanged
{
    self.slider.value = round(self.slider.value);
    self.noteLabel.text = [NSString stringWithFormat:@"%.0f", self.slider.value];
}

// 0xBx
- (void)receivedControlChangeChannel:(uint8_t)channel controller:(uint8_t)controller value:(uint8_t)value;
{
	if ((controller & 0xF0) == 0x10)
	{
		NSLog(@"Mackie V-Pot %02x direction %02x delta %02x", controller, value & 0x40, value & 0x3F);
	}
	
	if ((controller & 0xF0) == 0x30)
	{
		NSLog(@"Mackie Set LED Ring %02x to %02x", controller, value);
	}
	
	if ((controller & 0xF0) == 0x40)
	{
	}
}

static void ReadCallBackProc(const MIDIPacketList *pktlist, void *refCon, void *srcConnRefCon)
{
	ViewController	*vc   = (__bridge ViewController *)refCon;
}

static void InputPortCallback(const MIDIPacketList * pktlist, void * refCon, void * connRefCon)
{
	MIDIPacket		*packet = (MIDIPacket *)pktlist->packet;
	ViewController	*vc   = (__bridge ViewController *)refCon;
	
	for (unsigned int j = 0; j < pktlist->numPackets; j++)
	{
		uint8_t * d = packet->data;
		uint8_t   c = d[0] & 0xF0;
		
		switch (d[0] & 0xF0)
		{
			case 0xB0:
				[vc receivedControlChangeChannel:c controller:d[1] value:d[2]];
				break;
		}
		packet = MIDIPacketNext(packet);
	}
}
@end
