using DMLib;

namespace LprLib
{
  /**
   * This errordomain contains some errors which may occur when you work with LprSend.
   */
  public errordomain LprError
  {
    /* Hostname not found Error */
    HOSTNAME_NOT_FOUND,

    /* Printer return an Error */
    PRINTER_ERROR,

    /* Configuration not found Error */
    CONFIG_NOT_FOUND,
  }

  /**
   * This class includes all methods to read a LprSender
   * It send send files to the remote printer
   */
  public class LprSend : GLib.Object
  {
    /**
     * This file is sent to the remote printer
     */
    string? input_file_name = null;

    /**
     * This socket for the connection
     */
    Socket? socket = null;

    /**
     * The max size of one transmit
     */
    public uint64 max_size = 16*1024;

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
    public LprSend( string hostname, string file_path, uint16 port = 515 ) throws LprError, Error
    {
      /* Set the file control */
      File file = File.new_for_path( file_path );

      /* Set the input_file_name */
      this.input_file_name = file_path;

      /* Set the basename of the for the config */
      string input_file_basename = file.get_basename( );

      /* Initializes the config */
      this.config = new HashTable<char?, string?> ( str_hash, str_equal );

      /* Host name */
      this.config.insert( 'H', GLib.Environment.get_host_name( ) );

      /* Name of source file */
      this.config.insert( 'N', input_file_basename );

      /* User identification */
      this.config.insert( 'P', GLib.Environment.get_user_name( ) );

      /* Print file with 'pr' format */
      this.config.insert( 'p', "dfA000" + GLib.Environment.get_host_name( ) );

      /*
       * Further configuration:
       *
       * this.config.insert( 'C', null );  // Class for banner page
       * this.config.insert( 'I', null );  // Indent Printing
       * this.config.insert( 'J', null );  // Job name for banner page
       * this.config.insert( 'L', null );  // Print banner page
       * this.config.insert( 'M', null );  // Mail When Printed
       * this.config.insert( 'S', null );  // Symbolic link data
       * this.config.insert( 'T', null );  // Title for pr
       * this.config.insert( 'U', null );  // Unlink data file
       * this.config.insert( 'W', null );  // Width of output
       * this.config.insert( '1', null );  // troff R font
       * this.config.insert( '2', null );  // troff I font
       * this.config.insert( '3', null );  // troff B font
       * this.config.insert( '4', null );  // troff S font
       * this.config.insert( 'c', null );  // Plot CIF file
       * this.config.insert( 'd', null );  // Print DVI file
       * this.config.insert( 'f', null );  // Print formatted file
       * this.config.insert( 'g', null );  // Plot file
       * this.config.insert( 'k', null );  // Reserved for use by Kerberized LPR clients and servers
       * this.config.insert( 'l', null );  // Print file leaving control characters
       * this.config.insert( 'n', null );  // Print ditroff output file
       * this.config.insert( 'o', null );  // Print Postscript output file
       * this.config.insert( 'r', null );  // File to print with FORTRAN carriage control
       * this.config.insert( 't', null );  // Print troff output file
       * this.config.insert( 'v', null );  // Print raster file
       */

      /* Initializes the socket connection */
      this.socket = new Socket( SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.TCP );

      /* Set the IP-Address from the remote Server */
      InetAddress address = get_ip( hostname );
      if( address != null )
      {
        /* Connect to Server! */
        InetSocketAddress inetaddress = new InetSocketAddress ( address, port );
        this.socket.connect( inetaddress );
      }
      else
      {
        /* Server not found! */
        throw new LprError.HOSTNAME_NOT_FOUND( "Could not found server( %s )!\n", hostname );
      }
    }

    /**
     * Resolve the IP Address from the hostname
     * @param hostname This is the hostname of the print_server
     * @retrun the IP Address of the hostname
     */
    public InetAddress? get_ip( string hostname ) throws Error
    {
      /* Try parse the IP-Address */
      InetAddress address = new InetAddress.from_string( hostname );
      if( address == null )
      {
        /* No IP-Address -> Try to resolve the hostname */
        Resolver resolver = Resolver.get_default( );

        /* Resolve the IP-Addresses */
        List<InetAddress> addresses = resolver.lookup_by_name( hostname, null );

        /* Get the first IP-Address */
        unowned List<InetAddress> element = addresses.first( );
        address = element.data;
      }
      return address;
    }

    /**
     * Send the configruation to the remote printer
     * @param queue Print queue on the specified print server
     */
    public void send_configuration( string queue ) throws LprError, Error
    {
      /*
       * Send Directory prefix for the output file
       * config_transmit is the string which is sent to the remote Server
       * A config transmit must have a new line command at the ending
       */
      string config_transmit = "%c".printf( 0x02 ) + queue + "\n";
      this.socket.send( config_transmit.data );
      stdout.printf( "Start Config: " + config_transmit );


      /* receive_buffer is the buffer for the answer of the remote Server */
      uint8 receive_buffer[ 1 ];

      /*
       * Receive answer ( 0 if there wasn't an error ) 
       * len is length of the answer, maximum length is the receive_buffer size
       */
      size_t len = this.socket.receive( receive_buffer );
      if( len != 0 )
      {
        stdout.printf( "Empfangen: %d\n", receive_buffer[ 0 ] );
        if( receive_buffer[ 0 ] != 0 )
        {
          throw new LprError.PRINTER_ERROR( "Printer reported an error ( " + receive_buffer[ 0 ].to_string( "%d" ) + " )!" );
        }
      }

      /* Create config data string */
      string config_data = "";
      if( this.config != null )
      {
        this.config.foreach( ( c_key, c_value ) =>
        {
          if( c_value != null )
          {
            config_data += "%c%s\n".printf( c_key, c_value );
          }
        } );
      }
      else
      {
        throw new LprError.CONFIG_NOT_FOUND( "Cannot found printer configuration!" );
      }

      /* Send the server the length of the configuration */
      string config_info = "%c%s cfA000%s\n".printf( 0x02, config_data.length.to_string( ), GLib.Environment.get_host_name( ) );
      this.socket.send( config_info.data );
      stdout.printf( "Config info: " + config_info );

      /* Receive answer ( 0 if there wasn't an error ) */
      len = this.socket.receive( receive_buffer );
      if( len != 0 )
      {
        stdout.printf( "Empfangen: %d\n", receive_buffer[ 0 ] );
        if( receive_buffer[ 0 ] != 0 )
        {
          throw new LprError.PRINTER_ERROR( "Printer reported an error ( " + receive_buffer[ 0 ].to_string( "%d" ) + " )!" );
        }
      }

      /*
       * Send the server the configuration
       * A data transmit must have a 0 byte at the ending
       */
      uint8[ ] send_buffer = config_data.data;
      send_buffer += 0;
      this.socket.send( send_buffer );
      stdout.printf( "Config: \n" + config_data );

      /* Receive answer ( 0 if there wasn't an error ) */
      len = this.socket.receive( receive_buffer );
      if( len != 0 )
      {
        stdout.printf( "Empfangen: %d\n", receive_buffer[ 0 ] );
        if( receive_buffer[ 0 ] != 0 )
        {
          throw new LprError.PRINTER_ERROR( "Printer reported an error ( " + receive_buffer[ 0 ].to_string( "%d" ) + " )!" );
        }
      }
    }

    /**
     * Send the file to the remote printer
     * @param file_path This file is sent to the remote printer
     */
    public void send_file( ) throws LprError, Error
    {
      /* Prepare the input file for reading */
      File file = File.new_for_path ( this.input_file_name );
      FileInputStream @is = file.read( );

      /* Get the size of the input file */
      FileInfo file_info = file.query_info( "*", FileQueryInfoFlags.NONE );
      uint64 file_size = file_info.get_size( );

      /* Send the server the length of the input file */
      string data_info = "%c%s dfA000%s\n".printf( 0x03, file_size.to_string( ), GLib.Environment.get_host_name( ) );
      this.socket.send( data_info.data );
      stdout.printf( "\nData info: " + data_info );

      /* receive_buffer is the buffer for the answer of the remote Server */
      uint8 receive_buffer[ 1 ];

      /*
       * Receive answer ( 0 if there wasn't an error ) 
       * len is length of the answer, maximum length is the receive_buffer size
       */
      size_t len = this.socket.receive( receive_buffer );
      if( len != 0 )
      {
        stdout.printf( "Empfangen: %d\n", receive_buffer[ 0 ] );
        if( receive_buffer[ 0 ] != 0 )
        {
          throw new LprError.PRINTER_ERROR( "Printer reported an error ( " + receive_buffer[ 0 ].to_string( "%d" ) + " )!" );
        }
      }

      /*
       * Send the server the input file
       * size of one transmit
       */
      size_t size = (size_t)this.max_size;

      /* position of the file */
      uint64 position = 0;

      /* file_buffer is a part of the input_file */
      uint8[ ] file_buffer = new uint8[ this.max_size ];

      stdout.printf( "Last transmit:\n" );
      while( size == this.max_size )
      {
        file_buffer = new uint8[ this.max_size ];
        size = @is.read( file_buffer );

        /* Ende of file => end of transmit */
        if( size < this.max_size )
        {
          file_buffer[ size ] = 0;
          size ++;
        }
        this.socket.send( file_buffer[ 0 : size ] );

        position += size;

        float prozent = (float)position / ( file_size + 1 ) * 100;
        stdout.printf( "Send file part: Position=%llu, Size=%s (%2.2f%%)\r",position, size.to_string( "%5d" ), prozent );
      }
      stdout.printf( "\n" );

      /* Receive answer ( 0 if there wasn't an error ) */
      len = this.socket.receive( receive_buffer );
      if( len != 0 )
      {
        stdout.printf( "Empfangen: %d\n", receive_buffer[ 0 ] );
        if( receive_buffer[ 0 ] != 0 )
        {
          throw new LprError.PRINTER_ERROR( "Printer reported an error ( " + receive_buffer[ 0 ].to_string( "%d" ) + " )!" );
        }
      }
    }

    /**
     * Close the connection to the remote printer
     */
    public void close( ) throws LprError, Error
    {
      this.socket.close( );
    }
  }
}
