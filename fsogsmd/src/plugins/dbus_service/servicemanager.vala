/*
 * Copyright (C) 2009-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 *                         Simon Busch <morphis@gravedo.de>
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

public enum FsoGsm.ServiceState
{
    DISABLED,
    ENABLED,
    SUSPENDED
}

public abstract class FsoGsm.ServiceManager : FsoFramework.AbstractObject, FsoGsm.IServiceProvider
{
    private Gee.HashMap<Type,Service> services;
    private FsoFramework.Subsystem subsystem;
    private string serviceName;
    private string servicePath;

    public string service_path { get { return servicePath; } }
    public ServiceState state { get; protected set; default = ServiceState.DISABLED; }

    protected ServiceManager( FsoFramework.Subsystem subsystem, string serviceName, string servicePath )
    {
        this.services = new Gee.HashMap<Type,Service>();
        this.subsystem = subsystem;
        this.serviceName = serviceName;
        this.servicePath = servicePath;
    }

    public void registerService<T>( Service serviceObject )
    {
        services[typeof(T)] = serviceObject;
        subsystem.registerObjectForService<T>( serviceName, servicePath, serviceObject );
    }

    protected void unregisterService<T>()
    {
        if ( !services.contains( typeof(T) ) )
            return;
        subsystem.unregisterObjectForService<T>( serviceName, servicePath );
    }

    public T retrieveService<T>()
    {
        assert( services.contains( typeof(T) ) );
        return services[typeof(T)];
    }

    public void assignModem( FsoGsm.Modem modem )
    {
        foreach ( var service in services.values )
            service.assignModem( modem );
    }

    public override string repr()
    {
        return @"<>";
    }

    public abstract async bool enable();
    public abstract async void disable();
    public abstract async void suspend();
    public abstract async void resume();
}

// vim:ts=4:sw=4:expandtab
