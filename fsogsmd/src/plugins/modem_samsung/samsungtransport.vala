/*
 * Copyright (C) 2011-2012 Simon Busch <morphis@gravedo.de>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */

using GLib;

public class FsoGsm.SamsungIpcTransport : FsoFramework.BaseTransport
{
    public SamsungIpcTransport()
    {
        base( "" );
        setBuffered( false );
    }

    public void assign_fd( int fd )
    {
        this.fd = fd;
    }

    public override string repr()
    {
        return "<SamsungIpc (fd %d)>".printf( fd );
    }

    /**
     * We override the configure method here to be sure no configure options are set by
     * anyone.
     **/
    protected override void configure() { }

    /**
     * This will suspend the transport. After it is suspend we can't send any more bytes
     * to the remote side.
     **/
    public override bool suspend()
    {
        assert( logger.debug(@"Successfully suspended the transport!") );
        return true;
    }

    /**
     * Resume the transport so we can send and receive our bytes again.
     **/
    public override void resume()
    {
        assert( logger.debug(@"Successfully resumed transport!") );
    }
}

// vim:ts=4:sw=4:expandtab
