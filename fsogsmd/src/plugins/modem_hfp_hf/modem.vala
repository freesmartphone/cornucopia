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

        public async void new_connection( GLib.Socket fd, uint16 version ) throws DBusError, IOError
        {
            yield other.new_connection( fd, version );
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

        //
        // public API
        //

        public Modem( string device_path )
        {
            this.device_path = device_path;
            this.agent = new DelegateAgent( this );
        }

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

            return true;
        }

        public async override void close()
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

        public override string repr()
        {
            return "<>";
        }

        protected override FsoGsm.Channel channelForCommand( FsoGsm.AtCommand command, string query )
        {
            return null;
        }

        //
        // Bluez.IHandsfreeAgent
        //

        public async void new_connection( GLib.Socket fd, uint16 version ) throws DBusError, IOError
        {
            assert( logger.debug( @"New HFP HF connection" ) );
        }

        public async void release() throws DBusError, IOError
        {
            assert( logger.debug( @"HFP HF connection released" ) );
        }
    }
}

// vim:ts=4:sw=4:expandtab
