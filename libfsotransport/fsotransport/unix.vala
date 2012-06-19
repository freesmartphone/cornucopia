/*
 * Copyright (C) 2012 Simon Busch <morphis@gravedo.de>
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

/**
 * @class FsoFramework.UnixTransport
 *
 * FSO transport abstraction using a Unix file descriptor
 **/
public class FsoFramework.UnixTransport : FsoFramework.BaseTransport
{
    private int _real_fd = -1;

    public UnixTransport( int fd )
    {
        base( "" );
        _real_fd = fd;
    }

    public override bool open()
    {
        fd = _real_fd;
        return base.open();
    }

    public override void close()
    {
        assert( logger.debug( "Closing..." ) );

        if ( readwatch != 0 )
            Source.remove( readwatch );

        channel = null;
        fd = -1;

        assert( logger.debug( "Closed" ) );
    }
}

// vim:ts=4:sw=4:expandtab
