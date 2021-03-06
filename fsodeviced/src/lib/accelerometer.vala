/**
 * Copyright (C) 2009-2012 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

public abstract class FsoDevice.BaseAccelerometer : FsoFramework.AbstractObject
{
    public signal void accelerate( int x, int y, int z );

    public void setThreshold( int mg )
    {
    }

    public void setRate( uint ms )
    {
    }

    public abstract void start();

    public abstract void stop();

    public override string repr()
    {
        return "<>";
    }
}

// vim:ts=4:sw=4:expandtab
