/*
 * Copyright (C) 2009-2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 *               2012 Simon Busch <morphis@gravedo.de>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 */

using Gee;

/**
 * @class WrapSms
 *
 * A helper class
 */
public class WrapSms
{
    public Sms.Message message;
    public int index;

    public WrapSms( owned Sms.Message message, int index = -1 )
    {
        this.index = index;
        this.message = (owned) message;

        if ( this.message.type == Sms.Type.DELIVER )
        {
#if DEBUG
            debug( "WRAPSMS: Created for message hash %s", this.message.hash() );
#endif
        }
        else
        {
            FsoFramework.theLogger.warning( "SMS type %d not yet supported".printf( this.message.type ) );
        }
    }

    ~WrapSms()
    {
        if ( message.type == Sms.Type.DELIVER )
        {
#if DEBUG
            debug( "WRAPSMS: Destructed for message hash %s", this.message.hash() );
#endif
        }
    }
}

/**
 * @class WrapHexPdu
 *
 * A helper class
 */
public class WrapHexPdu
{
    public string hexpdu;
    public int tpdulen;
    public int transaction_index;

    public WrapHexPdu( string hexpdu, int tpdulen, int index = -1 )
    {
        this.hexpdu = hexpdu;
        this.tpdulen = tpdulen;
        this.transaction_index = index;
    }
}

/**
 * @interface SmsHandler
 */
public interface FsoGsm.SmsHandler : FsoFramework.AbstractObject
{
    public abstract ISmsStorage storage { get; set; }

    public abstract async void syncWithSim();

    public abstract async void handleIncomingSmsOnSim( uint index );
    public abstract async void handleIncomingSms( string hexpdu, int tpdulen );
    public abstract async void handleIncomingSmsReport( string hexpdu, int tpdulen );

    public abstract uint16 lastReferenceNumber();
    public abstract uint16 nextReferenceNumber();

    public abstract Gee.ArrayList<WrapHexPdu> formatTextMessage( string number, string contents, bool requestReport );
    public abstract void storeTransactionIndizesForSentMessage( Gee.ArrayList<WrapHexPdu> hexpdus );
}

/**
 * @class AbstractSmsHandler
 *
 * An abstract SMS message handler which implements most parts for handling
 * incoming and outgoing message and only requires a subclass to implement
 * the real actions like acknowledging a message or reading one from the SIM card.
 **/
public abstract class FsoGsm.AbstractSmsHandler : FsoGsm.SmsHandler, FsoFramework.AbstractObject
{
    public ISmsStorage storage { get; set; }

    protected abstract async string retrieveImsiFromSIM();
    protected abstract async void fetchMessagesFromSIM();
    protected abstract async bool readSmsMessageFromSIM( uint index, out string hexpdu, out int tpdulen );
    protected abstract async bool removeSmsMessageFromSIM( uint index );
    protected abstract async bool acknowledgeSmsMessage( int id );

    //
    // private
    //

    private void onModemStatusChanged( FsoGsm.Modem modem, FsoGsm.Modem.Status status )
    {
        if ( status == Modem.Status.ALIVE_SIM_READY )
            Idle.add( () => { syncWithSim(); return false; } );
    }

    //
    // protected
    //

    protected AbstractSmsHandler()
    {
        if ( theModem == null )
            logger.warning( "SMS Handler created before modem" );
        else theModem.signalStatusChanged.connect( onModemStatusChanged );
    }

    //
    // public API
    //

    public uint16 lastReferenceNumber()
    {
        return storage.last_reference_number();
    }

    public uint16 nextReferenceNumber()
    {
        return storage.next_reference_number();
    }

    public async void syncWithSim()
    {
        string imsi = yield retrieveImsiFromSIM();
        storage = SmsStorageFactory.create( "default", imsi == "" || imsi == null ? "unknown" : imsi );

        yield fetchMessagesFromSIM();
    }

    public Gee.ArrayList<WrapHexPdu> formatTextMessage( string number, string contents, bool requestReport )
    {
        uint16 inref = nextReferenceNumber();
        int byteOffsetForRefnum;
        var hexpdus = new Gee.ArrayList<WrapHexPdu>();

        assert( logger.debug( @"using reference number $inref" ) );

        var smslist = Sms.text_prepare( contents, inref, true, out byteOffsetForRefnum );

        assert( logger.debug( @"message prepared in $(smslist.length()) smses" ) );

        smslist.foreach ( (element) => {
            unowned Sms.Message msgelement = (Sms.Message) element;
            // FIXME: encode service center address?
            //msgelement.sc_addr.from_string( "+490000000" );
            // encode destination address
            msgelement.submit.daddr.from_string( number );
            // encode report request
            msgelement.submit.srr = requestReport;
            // decode to hex pdu
            var tpdulen = 0;
            var hexpdu = msgelement.toHexPdu( out tpdulen );
            assert( tpdulen > 0 );
            hexpdus.add( new WrapHexPdu( hexpdu, tpdulen ) );
        } );

        assert( logger.debug( @"message encoded in $(hexpdus.size) hexpdus" ) );

        return hexpdus;
    }

    public async void handleIncomingSmsOnSim( uint index )
    {
        bool result = false;
        string hexpdu = "";
        int tpdulen = 0;

        if ( !yield readSmsMessageFromSIM( index, out hexpdu, out tpdulen ) )
        {
            logger.error( @"Could not read SMS message with index $(index) from SIM" );
            return;
        }

        // we're not keeping a backup of the SMS message on the SIM card
        if ( !yield removeSmsMessageFromSIM( index ) )
            logger.error( @"Could not remove SMS message with index $(index) from SIM" );

        yield handleIncomingSms( hexpdu, tpdulen );
    }

    public async void handleIncomingSms( string hexpdu, int tpdulen )
    {
        uint16 ref_num = 0;
        uint8 max_msgs = 0, seq_num = 0;
        var sms_service = theModem.theDevice<FreeSmartphone.GSM.SMS>();

        var message = Sms.Message.newFromHexPdu( hexpdu, tpdulen );
        if ( message == null )
        {
            logger.warning( @"Can't parse incoming SMS" );
            return;
        }

        // FIXME check wether this message needs a report

        if ( !message.extract_concatenation( out ref_num, out max_msgs, out seq_num ) )
        {
            assert( logger.debug( @"Got a new SMS from $(message.number()) with content: $(message.to_string())" ) );
            sms_service.incoming_text_message( message.number(), message.timestamp().to_string(), message.to_string() );
        }
        else
        {
            if ( storage.add_message_fragment( message, ref_num, max_msgs, seq_num ) == SmsMessageStatus.COMPLETE )
            {
                var complete_message = storage.extract_message( message.hash() );
                if ( complete_message != null )
                {
                    assert( logger.debug( @"Got a new SMS from $(complete_message.number) with content: $(complete_message.content)" ) );
                    sms_service.incoming_text_message( complete_message.number, complete_message.timestamp, complete_message.content );
                }
                else
                {
                    logger.error( "Could not extract a complete message from SMS storage" );
                }
            }
        }
    }

    public async void handleIncomingSmsReport( string hexpdu, int tpdulen )
    {
        var sms = Sms.Message.newFromHexPdu( hexpdu, tpdulen );
        if ( sms == null )
        {
            logger.warning( @"Can't parse SMS Status Report" );
            return;
        }

        var number = sms.number();
        var reference = sms.status_report.mr;
        var status = sms.status_report.st;
        var text = sms.to_string();

#if DEBUG
        debug( @"sms report addr: $number" );
        debug( @"sms report ref: $reference" );
        debug( @"sms report status: $status" );
        debug( @"sms report text: '$text'" );
#endif

        var transaction_index = storage.confirm_pending_message( reference );

        if ( transaction_index >= 0 )
        {
            var obj = theModem.theDevice<FreeSmartphone.GSM.SMS>();
            obj.incoming_message_report( transaction_index, status.to_string(), number, text );
        }
    }

    public void storeTransactionIndizesForSentMessage( Gee.ArrayList<WrapHexPdu> hexpdus )
    {
        storage.add_pending_message_fragments( hexpdus.to_array() );
    }

    public override string repr()
    {
        return storage != null ? storage.repr() : "<None>";
    }
}

// vim:ts=4:sw=4:expandtab
