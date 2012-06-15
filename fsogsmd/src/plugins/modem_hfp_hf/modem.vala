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
    class Modem : FsoGsm.AbstractModem, Bluez.IHandsfreeAgent
    {
        private const string CHANNEL_NAME = "main";
        private string device_path;

        //
        // private
        //

        private async void register_agent()
        {
            var hf_gateway = yield Bus.get_proxy<Bluez.IHandsfreeGateway>( BusType.SYSTEM, "org.bluez", device_path );
            yield hf_gateway.register_agent( (ObjectPath) "/org/freesmartphone/GSM/Device" );
        }

        private async void unregister_agent()
        {
            var hf_gateway = yield Bus.get_proxy<Bluez.IHandsfreeGateway>( BusType.SYSTEM, "org.bluez", device_path );
            yield hf_gateway.unregister_agent( (ObjectPath) "/org/freesmartphone/GSM/Device" );
        }

        //
        // public API
        //

        public Modem( string device_path )
        {
            this.device_path = device_path;
        }

        public async override bool open()
        {
            return true;
        }

        public async override void close()
        {
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
