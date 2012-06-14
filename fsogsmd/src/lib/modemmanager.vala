/*
 * Copyright (C) 2012 Simon Busch <morphis@gravedo.de>
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

namespace FsoGsm
{
    public abstract class ModemManager : FsoFramework.AbstractObject
    {
        private Gee.ArrayList<Modem> _modems;

        //
        // protected
        //

        protected abstract void on_modem_registration( Modem modem );
        protected abstract void on_modem_deregistration( Modem modem );

        //
        // public API
        //

        public ModemManager()
        {
            _modems = new Gee.ArrayList<Modem>();
        }

        public async void register_modem( FsoGsm.Modem modem )
        {
            _modems.add( modem );
            on_modem_registration( modem );
        }

        public async void unregister_modem( FsoGsm.Modem modem )
        {
            _modems.remove( modem );
            on_modem_deregistration( modem );
        }

        public override string repr()
        {
            return @"<>";
        }
    }
}

// vim:ts=4:sw=4:expandtab
