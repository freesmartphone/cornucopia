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
    public class Manager : FsoFramework.AbstractObject, FsoGsm.IBluetoothProfile
    {
        private FsoGsm.BluetoothManager _bt_manager = new FsoGsm.BluetoothManager();
        private const string HFP_AG_UUID = "0000111f-0000-1000-8000-00805f9b34fb";
        private Gee.HashMap<string,HfpHf.Modem> _modems;

        //
        // private
        //

        private async void initialize()
        {
            assert( logger.debug( @"Registering for HFP AG bluetooth profile" ) );
            yield _bt_manager.register_profile( HFP_AG_UUID, this );
        }

        //
        // public
        //

        public Manager()
        {
            _modems = new Gee.HashMap<string,HfpHf.Modem>();
            Idle.add( () => { initialize(); return false; } );
        }

        //
        // FsoGsm.IBluetoothProfile
        //

        public async bool probe( string device_path )
        {
            assert( logger.debug( @"HFP HF profile is active on device $device_path now" ) );

            if ( _modems.contains( device_path ) )
            {
                logger.warning( @"Device $device_path is already controlled by us!" );
                return false;
            }

            var modem = new HfpHf.Modem( device_path );
            theModemManager.register_modem( modem );

            _modems.set( device_path, modem );

            return true;
        }

        public async void remove( string device_path )
        {
            assert( logger.debug( @"HFP HF profile was disabled on device $device_path" ) );

            var modem = _modems.get( device_path );
            if ( modem == null )
            {
                logger.error( @"Bluetooth device $device_path was removed but we don't have a modem for it" );
                return;
            }

            theModemManager.unregister_modem( modem );
            _modems.unset( device_path );
        }

        public override string repr()
        {
            return @"<>";
        }
    }

    Manager manager = null;
}

/**
 * This function gets called on plugin initialization time.
 * @return the name of your plugin here
 * @note that it needs to be a name in the format <subsystem>.<plugin>
 * else your module will be unloaded immediately.
 **/
public static string fso_factory_function( FsoFramework.Subsystem subsystem ) throws Error
{
    FsoFramework.theLogger.debug( "fsogsm.modem_hfp_hf fso_factory_function" );
    HfpHf.manager = new HfpHf.Manager();
    return "fsogsmd.modem_hfp_hf";
}

[ModuleInit]
public static void fso_register_function( TypeModule module )
{
    // do not remove this function
}

/**
 * This function gets called on plugin load time.
 * @return false, if the plugin operating conditions are present.
 * @note Some versions of glib contain a bug that leads to a SIGSEGV
 * in g_module_open, if you return true here.
 **/
/*public static bool g_module_check_init( void* m )
{
    var ok = FsoFramework.FileHandling.isPresent( Kernel26.SYS_CLASS_LEDS );
    return (!ok);
}
*/

// vim:ts=4:sw=4:expandtab
