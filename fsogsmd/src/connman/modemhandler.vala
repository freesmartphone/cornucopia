/*
 * Copyright (C) 2011 Simon Busch <morphis@gravedo.de>
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
 **/

using GLib;

public class FsoGsm.ModemHandler : FsoFramework.AbstractObject
{
    private const string DEFAUTL_IMSI = "262010123456789";

    private FreeSmartphone.Usage usage;
    private FreeSmartphone.GSM.SIM sim_service;
    private FreeSmartphone.GSM.PDP pdp_service;
    private FreeSmartphone.GSM.Device device_service;
    private FreeSmartphone.GSM.Network network_service;
    private FreeSmartphone.Data.World world_service;

    /* these are the parts we need as interface to the connman core */
    private Connman.Device? modem_device;
    private Connman.Network? network;
    private Connman.IpAddress ipaddr;

    /* local informations about the modem state */
    private bool initialized;
    private bool resource_locked;
    private bool supports_gprs;
    private bool connected = false;
    private int signal_strength;
    private string operator_name;
    private string mccmnc;
    private uint watch = 0;

    /**
     * Reset internal data structure
     **/
    private void reset_internal_data()
    {
        resource_locked = false;
        signal_strength =  0;
        supports_gprs = false;
        operator_name = "";
    }

    /**
     * Signal handler for Usage service. Is triggered whenever a resource changes
     * its availability.
     **/
    private void on_resource_available( string name, bool availability )
    {
        if ( name == "GSM" )
        {
            if ( availability && !resource_locked )
            {
                request_resource();
            }
            else if ( !availability && resource_locked )
            {
                assert( logger.debug( @"GSM resource has gone; releasing modem device ..." ) );
                release_modem_device();
                resource_locked = false;
            }
        }
    }

    /**
     * Check modem for correct registration status
     **/
    private async void check_registration()
    {
        try
        {
            var device_status = yield device_service.get_device_status();
            if ( device_status <= FreeSmartphone.GSM.DeviceStatus.ALIVE_SIM_READY )
                return;

            if ( network != null )
            {
                logger.debug( @"We already have a network created for the curent device; ignoring ..." );
                return;
            }

            string imsi = modem_device.get_ident();
            network = new Connman.Network( imsi, Connman.NetworkType.CELLULAR );
            if ( network == null )
            {
                logger.error( @"Could not create a new network for our current device" );
                return;
            }

            ipaddr.clear();

            network.set_group( "fsogsm" );
            network.set_available( true );
            network.set_associating( false );
            network.set_connected( false );
            network.set_index( -1 );
            network.set_string( "Operator", operator_name );
            network.set_strength( (uint8) signal_strength );

            modem_device.add_network( network );

            assert( logger.debug( @"Successfully create a new network for our cellular device" ) );
        }
        catch ( Error err )
        {
            logger.error( @"Cannot check modem registration status" );
        }
    }

    /**
     * Create a new default device and register it to the internal connman core.
     * The device can later identified by the IMSI supplied by the modem.
     **/
    private async bool create_modem_device()
    {
        string imsi = DEFAUTL_IMSI;
        bool result = true;
        int rc = 0;

        if ( modem_device != null )
            return false;

        try
        {
            var info = yield sim_service.get_sim_info();
            imsi = info.lookup( "imsi" ) as string;
            imsi = ( imsi == null ) ? DEFAUTL_IMSI : imsi;

            modem_device = new Connman.Device( imsi, Connman.DeviceType.CELLULAR );
            if ( modem_device == null )
            {
                logger.error( @"Failed to create a new cellular device instance" );
                return false;
            }

            modem_device.set_ident( imsi );

            if ( ( rc = modem_device.register() ) != 0 )
            {
                logger.error( @"Failed to register our cellular device with connmand (rc = $(rc))" );
                modem_device = null;
                return false;
            }

            assert( logger.debug( @"Created a new network device successfully" ) );
        }
        catch ( Error err )
        {
            logger.error( @"Can't create default network device: $(err.message)" );
            result = false;
        }

        return result;
    }

    private void release_modem_device()
    {
        if ( modem_device == null )
            return;

        if ( network != null )
        {
            modem_device.remove_network( network );
            network = null;
        }

        modem_device.unregister();
        modem_device = null;

        assert( logger.debug( @"Successfully released modem device from connman" ) );
    }

    private T value_from_variant<T>(Variant? vt, VariantType type, T alternative)
    {
        if ( vt == null || !vt.is_of_type( type ) )
            return alternative;

        if ( type == VariantType.STRING )
                return (T) vt.get_string();
        else if ( type == VariantType.INT32 )
                return (T) vt.get_int32();

        return alternative;
    }

    /**
     * When network status has changed extract relevant information and supply
     * it the our network object.
     **/
    private async void on_modem_network_status_changed( HashTable<string,Variant> status )
    {
        Variant? v0 = status.lookup( "provider" );
        operator_name = value_from_variant<string>( v0, VariantType.STRING, "unknown" );

        Variant? v1 = status.lookup( "strength" );
        signal_strength = value_from_variant<int>( v1, VariantType.INT32, 0 );

        Variant? v2 = status.lookup( "code" );
        mccmnc = value_from_variant( v2, VariantType.STRING, "" );

        if ( network != null )
        {
            network.set_strength( (uint8) signal_strength );
            network.set_string( "Operator", operator_name );
        }
    }

    /**
     * When device status has changed we have to register/remove our network
     * object from the connman core.
     **/
    private void on_modem_device_status_changed( FreeSmartphone.GSM.DeviceStatus status )
    {
        assert( logger.debug( @"Got modem status $(status)" ) );

        if ( status == FreeSmartphone.GSM.DeviceStatus.ALIVE_REGISTERED )
        {
            check_registration();
        }
        else if ( status != FreeSmartphone.GSM.DeviceStatus.ALIVE_REGISTERED &&
                  status != FreeSmartphone.GSM.DeviceStatus.SUSPENDING &&
                  status != FreeSmartphone.GSM.DeviceStatus.RESUMING &&
                  network != null )
        {
            modem_device.remove_network( network );
            network = null;
        }
    }

    private void on_modem_sim_auth_status_changed( FreeSmartphone.GSM.SIMAuthStatus status )
    {
        assert( logger.debug( @"Got SIM auth status $(status)" ) );

        if ( status == FreeSmartphone.GSM.SIMAuthStatus.READY && modem_device != null )
        {
            assert( logger.debug( @"SIM card is now ready; creating a device for our modem ..." ) );
            create_modem_device();
        }
        else
        {
            release_modem_device();
        }
    }

    private async void setup_services()
    {
        try
        {
            device_service = Bus.get_proxy_sync<FreeSmartphone.GSM.Device>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                                      FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.NONE );

            sim_service = Bus.get_proxy_sync<FreeSmartphone.GSM.SIM>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                                      FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.NONE );

            network_service = Bus.get_proxy_sync<FreeSmartphone.GSM.Network>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                                      FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.NONE );

            pdp_service = Bus.get_proxy_sync<FreeSmartphone.GSM.PDP>( BusType.SYSTEM, FsoFramework.GSM.ServiceDBusName,
                                      FsoFramework.GSM.DeviceServicePath, DBusProxyFlags.NONE );

            sim_service.auth_status.connect( on_modem_sim_auth_status_changed );
            device_service.device_status.connect( on_modem_device_status_changed );
            network_service.status.connect( on_modem_network_status_changed );

            var sim_auth_status = yield sim_service.get_auth_status();
            assert( logger.debug( @"sim_auth_status = $(sim_auth_status)" ) );
            if ( sim_auth_status == FreeSmartphone.GSM.SIMAuthStatus.READY )
            {
                assert( logger.debug( @"SIM card is READY; creating device for our modem ..." ) );
                create_modem_device();
            }

            assert( logger.debug( @"Setup of relevant services is done" ) );
        }
        catch ( GLib.Error err )
        {
            logger.error( @"Failed to setup necessary GSM services" );
        }
    }

    private async void request_resource()
    {
        try
        {
            yield usage.request_resource( "GSM" );
            resource_locked = true;
            yield setup_services();

            if ( watch > 0 )
                GLib.Source.remove( watch );

            assert( logger.debug( @"Successfully requested GSM resource" ) );
        }
        catch ( Error err )
        {
            logger.error( @"Could not request GSM resource from usage system; trying again in five seconds ..." );
            watch = Timeout.add_seconds( 5, () => { request_resource(); return false; } );
        }
    }

    private async void release_resource()
    {
        try
        {
            release_modem_device();
            yield usage.release_resource( "GSM" );
            resource_locked = false;
        }
        catch ( Error err )
        {
            logger.error( @"Failed to release GSM resource: $(err.message)" );
        }
    }

    //
    // public API
    //

    public ModemHandler()
    {
        initialized = false;
    }

    public override string repr()
    {
        return "<>";
    }

    public async void initialize()
    {
        string[] resources = { };

        logger.info( "Initializing ..." );

        if ( initialized )
        {
            return;
        }

        reset_internal_data();

        try
        {
            usage = Bus.get_proxy_sync<FreeSmartphone.Usage>( BusType.SYSTEM, FsoFramework.Usage.ServiceDBusName,
                                                              FsoFramework.Usage.ServicePathPrefix,
                                                              DBusProxyFlags.NONE );
            usage.resource_available.connect( on_resource_available );

            yield request_resource();
        }
        catch ( GLib.Error err )
        {
            logger.error( @"Can't register on usage service for listing to new resources" );
        }

        initialized = true;
    }

    /**
     * Establish PDP connection with registered network
     **/
    public async int connect_network()
    {
        logger.debug( @"Establishing GSM PDP connection ..." );

        if ( mccmnc.length == 0 )
        {
            logger.error( "We don't have mcc and mnc to retrieve correct APN for PDP connection" );
            return -Posix.EINVAL;
        }

        try
        {
            logger.debug( @"mccmnc = $(mccmnc)" );
            var apns = yield world_service.get_apns_for_mcc_mnc( mccmnc );
            if ( apns.length == 0 )
            {
                logger.error( "Invalid mcc and mnc wihtout context information!" );
                return -Posix.EINVAL;
            }

            var apn = apns[0];
            logger.debug( @"Using apn = \"$(apn.apn)\", username = \"$(apn.username)\", password = \"$(apn.password)\"");
            yield pdp_service.set_credentials( apn.apn, apn.username, apn.password );
            yield pdp_service.activate_context();
        }
        catch ( Error err )
        {
            logger.error( @"Failed to activate PDP connection: $(err.message)" );
            return -1;
        }

        // FIXME set ipaddr, method ...

        network.set_connected( true );
        connected = true;

        return 0;
    }

    /**
     * Realse current active PDP connection
     **/
    public async int disconnect_network()
    {
        logger.debug( @"Releasing GSM PDP connection ..." );

        try
        {
            yield pdp_service.deactivate_context();
        }
        catch ( Error err )
        {
            logger.error( @"Failed to deactivate PDP connection: $(err.message)" );
            return -1;
        }

        network.set_connected( false );
        connected = false;

        return 0;
    }

    public void shutdown()
    {
        logger.info( "Shuting down ..." );

        if ( connected )
            disconnect_network();

        if ( modem_device != null )
        {
            modem_device.remove_all_networks();
            modem_device.unregister();
            modem_device = null;
            network = null;
        }

        release_resource();
    }
}

// vim:ts=4:sw=4:expandtab
