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
 *
 */

using Gee;

namespace FsoGsm
{
    public const string SMS_STORAGE_DEFAULT_STORAGE_DIR = "/tmp/fsogsmd/sms";
    public const string SMS_STORAGE_SENT_UNCONFIRMED = "sent-unconfirmed";
    public const int SMS_STORAGE_DIRECTORY_PERMISSIONS = (int) Posix.S_IRUSR | Posix.S_IWUSR |
                                                               Posix.S_IXUSR | Posix.S_IRGRP |
                                                               Posix.S_IXGRP | Posix.S_IROTH |
                                                               Posix.S_IXOTH;

    public enum SmsMessageStatus
    {
        ALREADY_SEEN,
        INCOMPLETE,
        COMPLETE
    }

    public struct SmsMessage
    {
        public string number;
        public string status;
        public string content;
        public string timestamp;
    }

    public interface ISmsStorage : FsoFramework.AbstractObject
    {
        /**
         * Cleanup the complete storage. All stored objects will be removed and are not
         * available any longer. This will also reset the reference number counter to 0.
         **/
        public abstract void clean();

        /**
         * Add a fragment of a concatenated message to the storage. Once the message is
         * complete (all fragments are available in the storage) the return code will
         * change to SmsMessageStatus.COMPLETE.
         *
         * @param message Message fragment object to be add to the storage
         * @param ref_num Reference number of the message fragment
         * @param max_msgs Number of message fragments part of the concatenated message
         * @param seq_num Sequence number of the message.
         * @return Status of the concatenated message. See @SmsMessageStatus.
         **/
        public abstract SmsMessageStatus add_message_fragment( Sms.Message message, uint16 ref_num, uint8 max_msgs, uint8 seq_num );

        /**
         * Add fragments of a pending message. All fragments are stored within the storage
         * until they get confirmed.
         *
         * @param message List of the message fragments to add to the storage
         **/
        public abstract void add_pending_message_fragments( WrapHexPdu[] messages );

        /**
         * Confirm a pending message by it's reference number.
         *
         * @param netreference Reference number recieved with the confirmation report.
         * @return The index of the message within the storage or -1 if not all fragments
         *         of the message are confirmed or no message is confirmed with the
         *         supplied reference number.
         **/
        public abstract int confirm_pending_message( int netreference );

        /**
         * Extract a message from the storage. This is only possible for completed
         * concatenated messages and the message will be removed from storage after it is
         * successfully extracted.
         *
         * @param hash Hash of the message to extract.
         * @return The SMS message identified by the supplied hash or null if no message
         *         with the hash exists or the message is still incomplete.
         **/
        public abstract SmsMessage? extract_message( string hash );

        /**
         * Retrieve the last reference number used for a message.
         *
         * @return Last Reference number used.
         **/
        public abstract uint16 last_reference_number();

        /**
         * Retrieve the next reference number to use for sending a new message.
         *
         * @return Next reference number.
         **/
        public abstract uint16 next_reference_number();
    }

    public class SmsStorageFactory
    {
        /**
         * Create a new SMS storage for a given IMSI.
         **/
        public static ISmsStorage create( string type, string imsi )
        {
            return new SmsStorage( imsi );
        }
    }

    /**
     * @class SmsStorage
     *
     * A high level persistent SMS Storage abstraction.
     */
    public class SmsStorage : FsoFramework.AbstractObject, ISmsStorage
    {
        private string _storagedirprefix =  SMS_STORAGE_DEFAULT_STORAGE_DIR;
        private string _imsi;
        private string _storagedir;

        //
        // public API
        //

        public SmsStorage( string imsi )
        {
            _imsi = imsi;
            _storagedirprefix = config.stringValue( CONFIG_SECTION, "sms_storage_dir", SMS_STORAGE_DEFAULT_STORAGE_DIR );
            _storagedir = GLib.Path.build_filename( _storagedirprefix, imsi );
        }

        /**
         * Set the storage dir to use.
         * WARNING: should only used for testing purposes. In production environments
         * storage dir path is always read from the configuration file.
         *
         * @param storagedir Path to storage directory.
         **/
        public void set_storage_dir( string storagedir )
        {
            _storagedir = storagedir;
        }

        public void clean()
        {
            FsoFramework.FileHandling.removeTree( _storagedir );
        }

        public SmsMessageStatus add_message_fragment( Sms.Message message, uint16 ref_num, uint8 max_msgs, uint8 seq_num )
        {
            if ( message.type != Sms.Type.DELIVER )
            {
                logger.info( "Ignoring message with type %u (!= DELIVER)".printf( (uint)message.type ) );
                return SmsMessageStatus.ALREADY_SEEN;
            }

            var smshash = message.hash();
            var dirname = GLib.Path.build_filename( _storagedir, smshash );
            var filename = GLib.Path.build_filename( dirname, "%03u".printf( seq_num ) );
            if ( FsoFramework.FileHandling.isPresent( filename ) )
                return SmsMessageStatus.ALREADY_SEEN;

            if ( !FsoFramework.FileHandling.isPresent( dirname ) )
                GLib.DirUtils.create_with_parents( dirname, SMS_STORAGE_DIRECTORY_PERMISSIONS );

            // message is not present, save it now
            FsoFramework.FileHandling.writeBuffer( message, message.size(), filename, true );

            assert( logger.debug( @"fragment file $filename now present, checking for completeness..." ) );

            // check whether we have all fragments?
            for( int i = 1; i <= max_msgs; ++i )
            {
                var fragmentfilename = GLib.Path.build_filename( _storagedir, smshash, "%03u".printf( i ) );
                if( !FsoFramework.FileHandling.isPresent( fragmentfilename ) )
                {
                    assert( logger.debug( @"fragment file $fragmentfilename not present ==> INCOMPLETE" ) );
                    return SmsMessageStatus.INCOMPLETE;
                }

                assert( logger.debug( @"fragment file $fragmentfilename present" ) );
            }

            return SmsMessageStatus.COMPLETE;
        }

        public SmsMessage? extract_message( string hash )
        {
            SmsMessage? result = SmsMessage();
            var namecomponents = hash.split( "_" );
            var dirname = GLib.Path.build_filename( _storagedir, hash );
            var max_fragment = namecomponents[namecomponents.length-1].to_int();
            var smses = new Sms.Message[max_fragment-1] {};
            bool complete = true;
            bool info = false;

            if ( !FsoFramework.FileHandling.isPresent( dirname ) )
                return null;

            for( int i = 1; i <= max_fragment; ++i )
            {
                smses[i-1] = new Sms.Message();
                var filename = GLib.Path.build_filename( dirname, "%03u".printf( i ) );
                if ( ! FsoFramework.FileHandling.isPresent( filename ) )
                {
                    complete = false;
                    result.status = "incomplete";
                    smses[i-1] = null;
                }
                else
                {
                    string contents;

                    try
                    {
                        GLib.FileUtils.get_contents( filename, out contents );
                    }
                    catch ( GLib.Error e )
                    {
                        logger.error( @"Can't access SMS storage dir: $(e.message)" );
                        return result;
                    }

                    Memory.copy( smses[i-1], contents, Sms.Message.size() );

                    if ( !info )
                    {
                        result.number = smses[i-1].number();
                        result.timestamp = smses[i-1].timestamp().to_string();
                        info = true;
                    }
                }
            }

            if ( complete )
            {
                var smslist = new SList<weak Sms.Message>();
                for( int i = 0; i < max_fragment; ++i )
                {
                    if ( smses[i] != null )
                        smslist.append( smses[i] );
                }

                var text = Sms.decode_text( smslist );
                result.content = ( text != null ) ? text : "decode error";
            }
            else
            {
                result = null;
            }

            FsoFramework.FileHandling.removeTree( dirname );

            return result;
        }

        public void add_pending_message_fragments( WrapHexPdu[] messages )
        {
            string refnum = last_reference_number().to_string();
            string name = "";

            foreach ( var hexpdu in messages )
                name += @":$(hexpdu.transaction_index)";

            var dirname = GLib.Path.build_filename( _storagedir, SMS_STORAGE_SENT_UNCONFIRMED, name );
            if ( ! FsoFramework.FileHandling.isPresent( dirname ) )
                GLib.DirUtils.create_with_parents( dirname, SMS_STORAGE_DIRECTORY_PERMISSIONS );

            foreach ( var hexpdu in messages )
            {
                var filename = GLib.Path.build_filename( dirname, hexpdu.transaction_index.to_string() );
                FsoFramework.FileHandling.write( refnum, filename, true );
            }
        }

        public int confirm_pending_message( int netreference )
        {
            var dirname = GLib.Path.build_filename( _storagedir, SMS_STORAGE_SENT_UNCONFIRMED );
            var unconfirmed_messages = FsoFramework.FileHandling.listDirectory( dirname );

            foreach ( var message in unconfirmed_messages )
            {
                var components = message.split( ":" );
                foreach ( var component in components )
                {
                    if ( component.to_int() == netreference )
                    {
                        assert( logger.debug( @"Found reference ($netreference) of unconfirmed SMS:$component in $message" ) );

                        var filedirname = GLib.Path.build_filename( dirname, message );
                        var filename = GLib.Path.build_filename( filedirname, component );
                        var transaction_index = FsoFramework.FileHandling.read( filename ).to_int();

                        GLib.FileUtils.unlink( filename );
                        if ( GLib.DirUtils.remove( filedirname ) != 0 )
                        {
                            assert( logger.debug( @"$(strerror(errno)) (Not all fragments confirmed yet)" ) );
                            return -1;
                        }
                        else
                        {
                            assert( logger.debug( @"All fragments confirmed & removed directory. Returning index $transaction_index" ) );
                            return transaction_index;
                        }
                    }
                }
            }

            logger.warning( @"Did not find unconfirmed SMS for reference $netreference" );

            return -1;
        }

        public uint16 last_reference_number()
        {
            var filename = GLib.Path.build_filename( _storagedir, "refnum" );
            return (uint16) FsoFramework.FileHandling.readIfPresent( filename ).to_int();
        }

        public uint16 next_reference_number()
        {
            if ( !FsoFramework.FileHandling.isPresent( _storagedir ) )
                GLib.DirUtils.create_with_parents( _storagedir, SMS_STORAGE_DIRECTORY_PERMISSIONS );

            var filename = GLib.Path.build_filename( _storagedir, "refnum" );
            var number = FsoFramework.FileHandling.readIfPresent( filename );
            uint16 num = number == "" ? 0 : (uint16) number.to_int() + 1;
            FsoFramework.FileHandling.write( num.to_string(), filename, true );
            return num;
        }

        public override string repr()
        {
            return @"<$_imsi>";
        }
    }
}

// vim:ts=4:sw=4:expandtab
