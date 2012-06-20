/*
 * Copyright (C) 2012 Simon Busch
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

namespace HfpHf
{
    private class DelegateAgent : FsoGsm.Service, Bluez.IHandsfreeAgent
    {
        private Bluez.IHandsfreeAgent other;

        public DelegateAgent( Bluez.IHandsfreeAgent other )
        {
            this.other = other;
        }

        //
        // Bluez.IHandsfreeAgent
        //

        public async void new_connection( GLib.Socket socket, uint16 version ) throws DBusError, IOError
        {
            yield other.new_connection( socket, version );
        }

        public async void release() throws DBusError, IOError
        {
            yield other.release();
        }
    }

    class Modem : FsoGsm.AbstractModem, Bluez.IHandsfreeAgent
    {
        private const string CHANNEL_NAME = "main";
        private string device_path;
        private Bluez.IHandsfreeGateway hf_gateway;
        private DelegateAgent agent;
        private GLib.Socket _socket;
        private ServiceLevelConnection _slc;

        //
        // protected
        //

        protected async override void powerOff()
        {
            try
            {
                assert( logger.debug( @"Disconnecting from bluez device [$device_path] ..." ) );
                yield hf_gateway.disconnect();

                assert( logger.debug( @"Unregistering agent from bluetooth device [$device_path] ..." ) );
                yield hf_gateway.unregister_agent( (ObjectPath) parent.service_path );
                parent.unregisterService<Bluez.IHandsfreeAgent>();
            }
            catch ( GLib.Error e )
            {
                logger.error( @"Failed to disconnect from HFP AG: $(e.message)" );
            }
        }

        protected override void registerCustomAtCommands( Gee.HashMap<string,FsoGsm.AtCommand> commands )
        {
            HfpHf.registerCustomAtCommands( commands );
        }

        protected override FsoGsm.UnsolicitedResponseHandler createUnsolicitedHandler()
        {
            return new HfpHf.UnsolicitedResponseHandler( this );
        }

        //
        // public API
        //

        public Modem( string device_path )
        {
            this.device_path = device_path;
            this.agent = new DelegateAgent( this );
        }

        /**
         * We're completely replacing the base class behavior in open here because we
         * don't need any channel setup procedure at this time. Our channel is created a
         * little bit later after we're connected to the HFP AG. See new_connection(...)
         * for implementation details.
         **/
        public async override bool open()
        {
            try
            {
                hf_gateway = yield Bus.get_proxy<Bluez.IHandsfreeGateway>( BusType.SYSTEM, "org.bluez", device_path );

                assert( logger.debug( @"Registering agent for bluetooth device [$device_path] ..." ) );
                parent.registerService<Bluez.IHandsfreeAgent>( agent );
                yield hf_gateway.register_agent( (ObjectPath) parent.service_path );

                assert( logger.debug( @"Connecting with bluez device [$device_path] ..." ) );
                yield hf_gateway.connect();
            }
            catch ( GLib.Error e )
            {
                logger.error( @"Can't connect to HFP AG: $(e.message)" );
                return false;
            }

            assert( logger.debug( @"Successfully connected with bluetooth service." ) );

            return true;
        }

        public async override void close()
        {
            yield _slc.release();
            base.close();
            _socket = null;
        }

        public override string repr()
        {
            return "<>";
        }

        protected override FsoGsm.Channel channelForCommand( FsoGsm.AtCommand command, string query )
        {
            return channels[ CHANNEL_NAME ];
        }

        protected override CallHandler createCallHandler()
        {
            return new NullCallHandler();
        }

        protected override SmsHandler createSmsHandler()
        {
            return new NullSmsHandler();
        }

        protected override PhonebookHandler createPhonebookHandler()
        {
            return null;
        }

        protected override WatchDog createWatchDog()
        {
            return new NullWatchDog();
        }

        //
        // Bluez.IHandsfreeAgent
        //

        public async void new_connection( GLib.Socket socket, uint16 version ) throws DBusError, IOError
        {
            assert( logger.debug( @"New HFP HF connection" ) );

            advanceToState( FsoGsm.Modem.Status.INITIALIZING );

            // keep a reference to the socket otherwise our file descriptor will be closed
            _socket = socket;

            var transport = new FsoFramework.UnixTransport( socket.fd );
            var parser = new FsoGsm.StateBasedAtParser();
            var channel = new HfpHf.AtChannel( CHANNEL_NAME, transport, parser );
            registerChannel( CHANNEL_NAME, channel );

            var success = yield channel.open();
            if ( !success )
            {
                logger.error( @"Can't open main channel; closing modem ... " );
                yield this.close();
                return;
            }

            _slc = new ServiceLevelConnection( this, version );
            success = yield _slc.initialize();
            if ( !success )
            {
                logger.error( @"Failed to establish service level connection" );
                yield close();
                throw new DBusError.FAILED( "Failed to establish service level connection" );
            }

            advanceToState( FsoGsm.Modem.Status.ALIVE_SIM_READY );
        }

        public async void release() throws DBusError, IOError
        {
            close();
            assert( logger.debug( @"HFP HF connection released" ) );
        }
    }
}

// vim:ts=4:sw=4:expandtab
