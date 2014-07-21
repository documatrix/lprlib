using DMLib;

namespace LprLib
{
  /**
   * This class includes all methods to read a LprSender
   * It send send files to the remote printer
   */
  public class LprSend : GLib.Object
  {
    /**
     * This is the hostname of the print_server
     */
    string? print_server = null;

    /**
     * This file is sent to the remote printer
     */
    string? input_file_name = null;

    /**
     * Directory prefix for the output file
     */
    string? queue = null;

    /**
     * This socket for the connection
     */
    Socket? socket = null;

    /**
     * The max size of one transmit
     */
    uint64 max_size = 16*1024;

    /**
     * If noprint is set, the file will not printed
     */
    bool no_print = false;

    /**
     * The configuration for the remote printer
     */
    public HashTable<char?, string?>? config = null;

    /**
     * This constructor initializes the LprSender.
     * @param hostname This is the hostname of the print_server
     * @param file_path This file is sent to the remote printer
     * @param port The port of the remote printer
     * @retrun 0 if there wasn't an error.
     */
    public LprSend( string hostname, string file_path, uint16 port=515 )
    {
      File file = File.new_for_path( file_path );
      input_file_name = file_path;
      string input_file_basename = file.get_basename( );

      config = new HashTable<char?, string?> ( str_hash, str_equal );

      /* Host name */
      config.insert( 'H', GLib.Environment.get_host_name( ) );

      /* Name of source file */
      config.insert( 'N', input_file_basename );

      /* User identification */
      config.insert( 'P', GLib.Environment.get_user_name( ) );

      /* Print file with 'pr' format */
      config.insert( 'p', "dfA000" + GLib.Environment.get_host_name( ) );

      /*
       * Further configuration:
       *
       * config.insert( 'C', null ); // Class for banner page
       * config.insert( 'I', null ); // Indent Printing
       * config.insert( 'J', null ); // Job name for banner page
       * config.insert( 'L', null ); // Print banner page
       * config.insert( 'M', null ); // Mail When Printed
       * config.insert( 'S', null ); // Symbolic link data
       * config.insert( 'T', null ); // Title for pr
       * config.insert( 'U', null ); // Unlink data file
       * config.insert( 'W', null ); // Width of output
       * config.insert( '1', null ); // troff R font
       * config.insert( '2', null ); // troff I font
       * config.insert( '3', null ); // troff B font
       * config.insert( '4', null ); // troff S font
       * config.insert( 'c', null ); // Plot CIF file
       * config.insert( 'd', null ); // Print DVI file
       * config.insert( 'f', null ); // Print formatted file
       * config.insert( 'g', null ); // Plot file
       * config.insert( 'k', null ); // Reserved for use by Kerberized LPR clients and servers
       * config.insert( 'l', null ); // Print file leaving control characters
       * config.insert( 'n', null ); // Print ditroff output file
       * config.insert( 'o', null ); // Print Postscript output file
       * config.insert( 'r', null ); // File to print with FORTRAN carriage control
       * config.insert( 't', null ); // Print troff output file
       * config.insert( 'v', null ); // Print raster file
       */

      try
      {
        socket = new Socket( SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.TCP );
        InetAddress address = get_ip( hostname );
        if( address != null)
        {
          /* Connection to Server! */
          InetSocketAddress inetaddress = new InetSocketAddress ( address, port );
          socket.connect( inetaddress );
        }
        else
        {
          /* Server not found! */
          stderr.printf( "Could not found server( %s )!\n", hostname );
        }
      }
      catch( Error e ) 
      {
        /* Could not connect! */
        stderr.printf( "Could not connect to server( %s ): %s\n", hostname, e.message );
      }
    }

    /**
     * Resolve the IP Address from the hostname
     * @param hostname This is the hostname of the print_server
     * @retrun the IP Address of the hostname
     */
    public InetAddress? get_ip( string hostname )
    {
      InetAddress address = new InetAddress.from_string( hostname );
      if( address == null )
      {
        try 
        {
          Resolver resolver = Resolver.get_default( );
          List<InetAddress> addresses = resolver.lookup_by_name( hostname, null );

          unowned List<InetAddress> element = addresses.first( );
          if(element == null)
          {
            return null;
          }
          address = element.data;

        }
        catch( Error e )
        {
          stderr.printf( "Server not found( %s ): Could not resolve IP-Address!\n", hostname );
          return null;
        }
      }
      return address;
    }

    /**
     * Send the configruation to the remote printer
     * @param queue Directory prefix for the output file
     * @retrun 0 if there wasn't an error.
     */
    public bool send_configuration( string queue )
    {
      try
      {
        /* Send Directory prefix for the output file */
        string data = "%c".printf(0x02) + queue + "\n";
        socket.send( data.data );
        stdout.write( data.data );

        /* Receive answer ( 0 if there wasn't an error ) */
        uint8 receive_buffer[ 1 ];
        size_t len = socket.receive( receive_buffer );
        if( len != 0 )
        {
          stdout.printf( "Empfangen: %d\n", receive_buffer[ 0 ] );
          if( receive_buffer[ 0 ] != 0 )
          {
            stderr.printf( "Printer reported an error (%d)!", receive_buffer[ 0 ] );
            return false;
          }
        }

        /* Create config data string */
        data = "";
        if( config != null)
        {
          config.foreach((c_key, c_value) => 
          {
            if( c_value != null )
            {
              data += "%c%s\n".printf( c_key, c_value );
            }
          });
        }
        else
        {
          stderr.printf( "No configuration found!" );
          return false;
        }

        /* Send the server the length of the configuration */
        string text= "%c%s cfA000%s\n".printf( 0x02, data.length.to_string( ), GLib.Environment.get_host_name( ) );
        socket.send( text.data );
        stdout.write( text.data );

        /* Receive answer ( 0 if there wasn't an error ) */
        len = socket.receive( receive_buffer );
        if( len != 0 )
        {
          stdout.printf( "Empfangen: %d\n", receive_buffer[ 0 ] );
          if( receive_buffer[ 0 ] != 0 )
          {
            stderr.printf( "Printer reported an error (%d)!", receive_buffer[ 0 ] );
            return false;
          }
        }

        /* Send the server the configuration */
        uint8[ ] send_buffer = data.data;
        send_buffer += 0;
        socket.send( send_buffer );
        stdout.write( data.data );

        /* Receive answer ( 0 if there wasn't an error ) */
        len = socket.receive( receive_buffer );
        if( len != 0 )
        {
          stdout.printf( "Empfangen: %d\n", receive_buffer[ 0 ] );
          if( receive_buffer[ 0 ] != 0 )
          {
            stderr.printf( "Printer reported an error (%d)!", receive_buffer[ 0 ] );
            return false;
          }
        }
      }
      catch( Error e )
      {
        stderr.printf( "Failed to send Configruation!: %s", e.message );
        return false;
      }
      return true;
    }

    /**
     * Send the file to the remote printer
     * @param file_path This file is sent to the remote printer
     * @retrun 0 if there wasn't an error.
     */
    public bool send_file()
    {
      try
      {
        /* Prepare the input file for reading */
        File file = File.new_for_path ( input_file_name );
        string input_file_basename = file.get_basename( );
        FileInputStream @is = file.read( );

        /* Get the size of the input file */
        FileInfo file_info = file.query_info( "*", FileQueryInfoFlags.NONE );
        uint64 file_size = file_info.get_size( );

        /* Send the server the length of the input file */
        string data = "%c%s dfA000%s\n".printf( 0x03, file_size.to_string( ), GLib.Environment.get_host_name( ) );
        socket.send( data.data );
        stdout.write( data.data );

        /* Receive answer ( 0 if there wasn't an error ) */
        uint8 receive_buffer[ 1 ];
        size_t len = socket.receive( receive_buffer );
        if( len != 0 )
        {
          stdout.printf( "Empfangen: %d\n", receive_buffer[ 0 ] );
          if( receive_buffer[ 0 ] != 0 )
          {
            stderr.printf( "Printer reported an error (%d)!", receive_buffer[ 0 ] );
            return false;
          }
        }

        /* Send the server the input file */
        size_t size = (size_t)max_size;
        uint64 position = 0;

        uint8[ ] file_buffer = new uint8[ max_size ];

        stdout.printf( "Last tranmit:\n" );
        while( size == max_size )
        {
          file_buffer = new uint8[ max_size ];
          size = @is.read( file_buffer );

          /* Ende of file => end of transmit */
          if( size < max_size )
          {
            file_buffer[ size ]=0;
            size++;
          }
          socket.send( file_buffer[ 0 : size ] );

          position += size;

          float prozent = (float)position / file_size * 100;
          stdout.printf( "Send file part: Position=%llu, Size=%s (%2.2f%%)\r",position ,size.to_string( "%5d" ), prozent);

          
        }
        stdout.printf( "\n" );

        /* Receive answer ( 0 if there wasn't an error ) */
        len = socket.receive( receive_buffer );
        if( len != 0 )
        {
          stdout.printf( "Empfangen: %d\n", receive_buffer[ 0 ] );
          if( receive_buffer[ 0 ] != 0 )
          {
            stderr.printf( "Printer reported an error (%d)!", receive_buffer[ 0 ] );
            return false;
          }
        }
      }
      catch( Error e )
      {
        stderr.printf( "Failed to send File!: %s", e.message );
        return false;
      }
      return true;
    }

    /**
     * Close the connection to the remote printer
     * @retrun 0 if there wasn't an error.
     */
    public bool close( )
    {
      try
      {
        socket.close( );
      }
      catch( Error e )
      {
        stderr.printf( "Failed to close Connection!: %s", e.message );
        return false;
      }
      return true;
    }
  }
}
