/**
 * Copyright (C) 2009 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
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

/**
 * AT Command Interface and Abstract Base Class.
 *
 * The AtCommand class encapsulate generation and parsing of every kind of AT
 * command strings. To generate a command, use issue() or query(). The response
 * is to be fed into the parse() method. At commands are parsed using regular
 * expressions. The resulting fields are then picked into member variables.
 **/

public errordomain FsoGsm.AtCommandError
{
    UNABLE_TO_PARSE,
}

public abstract interface FsoGsm.AtCommand : FsoFramework.CommandQueueCommand, GLib.Object
{
    /* CommandQueueCommand */
    public abstract uint get_timeout();
    public abstract uint get_retry();
    public abstract string get_prefix();
    public abstract string get_postfix();
    public abstract bool is_valid_prefix( string line );

    /* AtCommand */
    public abstract void parse( string response ) throws AtCommandError;
    public abstract void parseMulti( string[] response ) throws AtCommandError;
    public abstract void parseTest( string response ) throws AtCommandError;

    /* Encoding/Decoding */
    public abstract string decodeString( string str );

    public abstract Constants.AtResponse validate( string[] response );
    public abstract Constants.AtResponse validateTest( string[] response );
    public abstract Constants.AtResponse validateURC( string response );
    public abstract Constants.AtResponse validateOk( string[] response );
    public abstract Constants.AtResponse validateMulti( string[] response );
}

public abstract class FsoGsm.AbstractAtCommand : FsoFramework.CommandQueueCommand, FsoGsm.AtCommand, GLib.Object
{
    protected Regex re;
    protected Regex tere;
    protected MatchInfo mi;
    protected string[] prefix;
    protected int length;

    construct
    {
        length = 1;
    }

    ~AbstractAtCommand()
    {
        warning( "DESTRUCT %s", Type.from_instance( this ).name() );
    }

    public string decodeString( string str )
    {
        if ( str == null || str.length == 0 )
            return "";
        var data = theModem.data();
        switch ( data.charset )
        {
            case "UCS2":
                return Conversions.ucs2_to_utf8( str );
            default:
                return str;
        }
    }

    public virtual void parse( string response ) throws AtCommandError
    {
        bool match;
        match = re.match( response, 0, out mi );

        if ( !match || mi == null )
        {
            theModem.logger.debug( @"Parsing error: '$response' does not match '$(re.get_pattern())'" );
            throw new AtCommandError.UNABLE_TO_PARSE( "" );
        }
    }

    public virtual void parseTest( string response ) throws AtCommandError
    {
        bool match;
        match = tere.match( response, 0, out mi );

        if ( !match || mi == null )
        {
            theModem.logger.debug( @"Parsing error: '$response' does not match '$(tere.get_pattern())'" );
            throw new AtCommandError.UNABLE_TO_PARSE( "" );
        }
    }

    public virtual void parseMulti( string[] response ) throws AtCommandError
    {
        assert_not_reached(); // pure virtual method
    }

    /**
     * Validate the terminal response for this At command
     **/
    public virtual Constants.AtResponse validateOk( string[] response )
    {
        var statusline = response[response.length-1];
        //FIXME: Handle nonverbose mode as well
        if ( statusline == "OK" )
        {
            return Constants.AtResponse.OK;
        }

        assert( theModem.logger.debug( @"Did not receive OK (instead '$statusline') for $(Type.from_instance(this).name())" ) );
        var errorcode = 0;

        if ( ! ( ":" in statusline ) )
        {
            return Constants.AtResponse.ERROR;
        }

        if ( statusline.has_prefix( "+CMS" ) )
        {
            errorcode += (int)Constants.AtResponse.CMS_ERROR_START;
            errorcode += (int)statusline.split( ":" )[1].to_int();
            return (Constants.AtResponse)errorcode;
        }
        else if ( statusline.has_prefix( "+CME" ) )
        {
            errorcode += (int)Constants.AtResponse.CME_ERROR_START;
            errorcode += (int)statusline.split( ":" )[1].to_int();
            return (Constants.AtResponse)errorcode;
        }
        else if ( statusline.has_prefix( "+EXT" ) )
        {
            errorcode += (int)Constants.AtResponse.EXT_ERROR_START;
            errorcode += (int)statusline.split( ":" )[1].to_int();
            return (Constants.AtResponse)errorcode;
        }
        return Constants.AtResponse.ERROR;
    }

    /**
     * Validate a response for this At command
     **/
    public virtual Constants.AtResponse validate( string[] response )
    {
        var status = validateOk( response );
        if ( status != Constants.AtResponse.OK )
        {
            return status;
        }

        // check whether we have received enough lines
        if ( response.length <= length )
        {
            theModem.logger.warning( @"Unexpected length $(response.length) for $(Type.from_instance(this).name())" );
            return Constants.AtResponse.UNEXPECTED_LENGTH;
        }

        try
        {
            parse( response[0] );
        }
        catch ( AtCommandError e )
        {
            theModem.logger.warning( @"Unexpected format for $(Type.from_instance(this).name())" );
            return Constants.AtResponse.UNABLE_TO_PARSE;
        }
        assert( theModem.logger.debug( @"Did receive a valid response for $(Type.from_instance(this).name())" ) );
        return Constants.AtResponse.VALID;
    }

    /**
     * Validate a test response for this At command
     **/
    public virtual Constants.AtResponse validateTest( string[] response )
    {
        var status = validateOk( response );
        if ( status != Constants.AtResponse.OK )
        {
            return status;
        }

        // second, check whether we have received enough lines
        if ( response.length <= length )
        {
            theModem.logger.warning( @"Unexpected test length $(response.length) for $(Type.from_instance(this).name())" );
            return Constants.AtResponse.UNEXPECTED_LENGTH;
        }

        try
        {
            parseTest( response[0] );
        }
        catch ( AtCommandError e )
        {
            assert( theModem.logger.debug( @"Unexpected test format for $(Type.from_instance(this).name())" ) );
            return Constants.AtResponse.UNABLE_TO_PARSE;
        }
        assert( theModem.logger.debug( @"Did receive a valid test response for $(Type.from_instance(this).name())" ) );
        return Constants.AtResponse.VALID;
    }

    /**
     * Validate a multiline response for this At command
     **/
    public virtual Constants.AtResponse validateMulti( string[] response )
    {
        var status = validateOk( response );
        if ( status != Constants.AtResponse.OK )
        {
            return status;
        }
        // <HACK>
        response.length--;
        // </HACK>
        try
        {
            // response[0:-1]?
            parseMulti( response );
            // <HACK>
            response.length++;
            // </HACK>
        }
        catch ( AtCommandError e )
        {
            // <HACK>
            response.length++;
            // </HACK>
            theModem.logger.warning( @"Unexpected format for $(Type.from_instance(this).name())" );
            return Constants.AtResponse.UNABLE_TO_PARSE;
        }
        assert( theModem.logger.debug( @"Did receive a valid response for $(Type.from_instance(this).name())" ) );
        return Constants.AtResponse.VALID;
    }

    /**
     * Validate an URC for this At command
     **/
    public virtual Constants.AtResponse validateURC( string response )
    {
        try
        {
            parse( response );
        }
        catch ( AtCommandError e )
        {
            theModem.logger.warning( @"Unexpected format for $(Type.from_instance(this).name())" );
            return Constants.AtResponse.UNABLE_TO_PARSE;
        }
        assert( theModem.logger.debug( @"Did receive a valid response for $(Type.from_instance(this).name())" ) );
        return Constants.AtResponse.VALID;
    }

    protected string to_string( string name )
    {
        var res = mi.fetch_named( name );
        if ( res == null )
            return ""; // indicates parameter not present
        return res;
    }

    protected int to_int( string name )
    {
        var res = mi.fetch_named( name );
        if ( res == null )
            return -1; // indicates parameter not present
        return res.to_int();
    }

    public virtual uint get_timeout()
    {
        return 2 * 60;
    }

    public virtual uint get_retry()
    {
        return 3;
    }

    public string get_prefix()
    {
        return "AT";
    }

    public string get_postfix()
    {
        return "\r\n";
    }

    public bool is_valid_prefix( string line )
    {
        if ( prefix == null ) // free format
            return true;
        for ( int i = 0; i < prefix.length; ++i )
        {
            if ( line.has_prefix( prefix[i] ) )
                return true;
        }
        return false;
    }
}

public class FsoGsm.V250terCommand : FsoGsm.AbstractAtCommand
{
    public string name;

    public V250terCommand( string name )
    {
        this.name = name;
        prefix = { "+ONLY_TERMINAL_SYMBOLS_ALLOWED" };
    }

    public string execute()
    {
        return name;
    }
}

public class FsoGsm.SimpleAtCommand<T> : FsoGsm.AbstractAtCommand
{
    private string name;
    /* regular operation */
    public T value;

    /* for test command */
    public string righthandside;
    public int min;
    public int max;

    public SimpleAtCommand( string name, bool prefixoptional = false )
    {
        this.name = name;
        var regex = prefixoptional ? """(\%s:\ )?""".printf( name ) : """\%s:\ """.printf( name );
        var testx = prefixoptional ? """(\%s:\ )?""".printf( name ) : """\%s:\ """.printf( name );

        if ( typeof(T) == typeof(string) )
        {
            regex += """"?(?P<righthandside>[^"]*)"?""";
            testx += """"?(?P<righthandside>.*)"?""";
        }
        else if ( typeof(T) == typeof(int) )
        {
            regex += """(?P<righthandside>\d+)""";
            testx += """(?P<min>\d+)-(?P<max>\d+)""";
        }
        else
        {
            assert_not_reached();
        }
        if ( !prefixoptional )
        {
            prefix = { name + ": " };
        }
        re = new Regex( regex );
        tere = new Regex( testx );
    }

    public override void parse( string response ) throws AtCommandError
    {
        base.parse( response );
        if ( typeof(T) == typeof(string) )
        {
            value = to_string( "righthandside" );
        }
        else if ( typeof(T) == typeof(int) )
        {
            value = to_int( "righthandside" );
        }
        else
        {
            assert_not_reached();
        }
    }

    public override void parseTest( string response ) throws AtCommandError
    {
        base.parseTest( response );
        if ( typeof(T) == typeof(string) )
        {
            righthandside = to_string( "righthandside" );
        }
        else if ( typeof(T) == typeof(int) )
        {
            min = to_int( "min" );
            max = to_int( "max" );
        }
        else
        {
            assert_not_reached();
        }
    }

    public string execute()
    {
        return name;
    }

    public string query()
    {
        return name + "?";
    }

    public string test()
    {
        return name + "=?";
    }

    public string issue( T val )
    {
        if ( typeof(T) == typeof(string) )
        {
            return "%s=\"%s\"".printf( name, (string)val );
        }
        else if ( typeof(T) == typeof(int) )
        {
            return "%s=%d".printf( name, (int)val );
        }
        else
        {
            assert_not_reached();
        }
    }

}

public class FsoGsm.CustomAtCommand : FsoGsm.AbstractAtCommand
{
}
