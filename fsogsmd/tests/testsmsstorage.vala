/*
 * Copyright (C) 2009-2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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
 *
 */

using GLib;
using FsoGsm;

FsoGsm.ISmsStorage create_storage( string storagedir )
{
    var storage = SmsStorageFactory.create( "default", IMSI );
    (storage as SmsStorage).set_storage_dir( storagedir );
    return storage;
}

void test_sms_storage_create()
{
    var storagedir = @"%s/fsogsmd/test_sms_storage_create".printf( GLib.Environment.get_tmp_dir() );
    var storage = create_storage( storagedir );
    assert( !FsoFramework.FileHandling.isPresent( storagedir ) );
}

void test_sms_storage_pending_message_with_confirmation()
{
    var storagedir = "%s/fsogsmd/test_sms_storage_pending_message_with_confirmation".printf( GLib.Environment.get_tmp_dir() );
    var storage = create_storage( storagedir );
    storage.clean();

    var transaction_index = 4;

    storage.add_pending_message_fragments( { new WrapHexPdu( pdu3, pdulength3, transaction_index ) } );
    assert( storage.confirm_pending_message( transaction_index ) == storage.last_reference_number() );

    storage.clean();
    storage.add_pending_message_fragments( { new WrapHexPdu( pdus2[0], pdulengths2[0], transaction_index ),
                                             new WrapHexPdu( pdus2[1], pdulengths2[1], transaction_index + 1 ) } );
    assert( storage.confirm_pending_message( transaction_index ) == -1 );
    assert( storage.confirm_pending_message( transaction_index + 1 ) == 0 );
}

void test_sms_storage_reference_number_handling()
{
    var storagedir = "%s/fsogsmd/test_sms_storage_reference_number_handling".printf( GLib.Environment.get_tmp_dir() );
    var storage = create_storage( storagedir );
    storage.clean();

    assert( storage.next_reference_number() == 0 );
    assert( storage.last_reference_number() == 0 );
    assert( storage.next_reference_number() == 1 );
    assert( storage.last_reference_number() == 1 );
    assert( storage.next_reference_number() == 2 );
    assert( storage.last_reference_number() == 2 );
}

void test_sms_storage_extract_message()
{
    uint16 ref_num = 0;
    uint8 max_msgs = 0, seq_num = 0;

    var storagedir = "%s/fsogsmd/test_sms_storage_extract_message".printf( GLib.Environment.get_tmp_dir() );
    var storage = create_storage( storagedir );
    storage.clean();

    var message0 = Sms.Message.newFromHexPdu( pdus2[0], pdulengths2[0] );
    message0.extract_concatenation( out ref_num, out max_msgs, out seq_num );
    assert( storage.add_message_fragment( message0, ref_num, max_msgs, seq_num ) == SmsMessageStatus.INCOMPLETE );

    var message1 = Sms.Message.newFromHexPdu( pdus2[1], pdulengths2[1] );
    message1.extract_concatenation( out ref_num, out max_msgs, out seq_num );
    assert( storage.add_message_fragment( message1, ref_num, max_msgs, seq_num ) == SmsMessageStatus.COMPLETE );

    var complete_message = storage.extract_message( message1.hash() );
    assert( complete_message != null );

    assert( complete_message.content != "" );
    assert( complete_message.number == "+491702720003" );
    assert( complete_message.timestamp == "09/10/30,15:46:55+04" );
}

void main( string[] args )
{
    Test.init( ref args );

    Test.add_func( "/SmsStorage/New", test_sms_storage_create );
    Test.add_func( "/SmsStorage/PendingMessageWithConfirmation", test_sms_storage_pending_message_with_confirmation );
    Test.add_func( "/SmsStorage/ReferenceNumberHandling", test_sms_storage_reference_number_handling );
    Test.add_func( "/SmsStorage/ExtractCompleteMessage", test_sms_storage_extract_message );

    Test.run();
}

// vim:ts=4:sw=4:expandtab
