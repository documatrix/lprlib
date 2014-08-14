using OpenDMLib;

namespace LprLib
{
  public class LprDaemon : GLib.Object
  {

    /* All connections */
    private Connection[ ] connections;

    /**
     * Sets the lpr_deamon
     * @param port the port of the deamon if this is not set it's 515
     * @param ip_address the ip_address of the deamon if this is not set it's the ip address of the server
     */
    public LprDaemon( uint16 port = 515 , string? ip_address = null )
    {
      /* IP-Address */
      InetAddress address = new InetAddress.loopback( SocketFamily.IPV4 );

      if( ip_address == null )
      {
        Resolver resolver = Resolver.get_default( );
        List<InetAddress*> addresses = resolver.lookup_by_name( "linux-88qt" , null );
        address = addresses.nth_data ( 0 );
        stdout.printf( "\n\nYour IP-Adresse: %s\n", address.to_string( ) );
      }
      else
      {
        address = new InetAddress.from_string( ip_address );
      }

      /* Socket Address of the daemon ( ip-address and port ) */
      InetSocketAddress inetaddress = new InetSocketAddress( address, port );

      /* The socket from the daemon */
      Socket socket = new Socket( SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.TCP );
      assert ( socket != null );

      try
      {
        socket.bind ( inetaddress, true );
      }
      catch( Error e )
      {
        stdout.printf( "\n\nError: %s \n\n", e.message );
      }

      stdout.printf( "Set listen_backlog\n" );
      socket.set_listen_backlog( 10 );
      socket.listen( );
      this.listen( socket );
    }

    /**
     * This method listen to the socket for a new connections
     * @param socket the socket of the daemon
     */
    public void listen( Socket socket )
    {
      #if GLIB_2_32
        new Thread<void*>( "connection", ( ) =>
        {
          while( true )
          {
            stdout.printf( "Waiting for new Connection....\n" );
            Socket connection_socket = socket.accept( );
            connections += new Connection( connection_socket );
          }
        });
      #else
        try
        {
          Thread.create<void*>( ( ) =>
          {
            while( true )
            {
              stdout.printf( "Waiting for new Connection....\n" );
              Socket connection_socket = socket.accept( );
              connections += new Connection( connection_socket );
            }
          }, true );
        }
        catch( Error e )
        {
          stdout.printf( "Error while creating Thread" );
        }
      #endif
    }

    /**
     * This method returns all connections
     * @return all connections
     */
    public Connection[ ] get_connections( )
    {
      return connections;
    }

    /**
     * This method delete a connection
     * @param connection The number of the connection which should be deleted. 0 is the first connection.
     */
    public void del_connection( uint64 connection )
    {
      Connection[ ] buffer_connections = connections;
      connections = null;
      for( int64 i = 0; i < connections.length; i ++ )
      {
        if( i != connection )
        {
          connections += buffer_connections[ i ];
        }
      }
    }

    /**
     * This method delete a all connection with status END or ERROR
     */
    public void del_finished_connection( )
    {
      Connection[ ] buffer_connections = connections;
      connections = null;
      for( int64 i = 0; i < buffer_connections.length; i ++ )
      {
        if( buffer_connections[ i ].status != Connection.END && buffer_connections[ i ].status != Connection.ERROR )
        {
          connections += buffer_connections[ i ];
        }
      }
    }
  }

  /**
   * This class includes all methods to interpret the data.
   * It write a output file and set variables.
   */
  public class Connection : GLib.Object
  {
    /* start to read data */
    public static const int16 BEGIN = 0;

    /* in filedata - block right now */
    public static const int16 FILEDATA = 2;

    /* in datablock-block right now */
    public static const int16 DATABLOCK = 3;

    /* end of the data */
    public static const int16 END = 4;

    /* error */
    public static const uint8 ERROR = -1;

    /* buffer uint8 array */
    private uint8[] buffer_string;

    /* the aktuell filesize ( it shows how many chars are left )*/
    private int64 temp_filesize = 0;

    /* connection */
    public Socket connection;

    /* Hostname */
    public string hostname = null;

    /* Filename */
    public string filename = null;

    /* PRQ - Name */
    public string prq_name = null;

    /* User Identification */
    public string user_identification = null;

    /* Job name */
    public string job_name = null;

    /* the size of the buffer */
    public int64 buffer_size;

    /* Title */
    public string title_text = null;

    /* Name of class for banner pages */
    public string class_name = null;

    /* Filesize */
    public int64 filesize = 0;

    /* output File */
    public FileStream output = null;

    /* Indenting count */
    public int64 indenting_count;

    /* Status */
    public int16 status = 0;

    /* Print file with pr */
    public string print_file_with_pr = null;

    /* The File name of the new file */
    public string save_name = null;

    /**
     * This method sets the connection
     * @param socket the socket of the connection
     * @param buffer_size the buffer length, if buffer_size isn't set it's 8192
     */
    public Connection( Socket socket, int64 buffer_size = 8192 )
    {
      this.connection = socket;
      this.buffer_size = buffer_size;
      #if GLIB_2_32
        new Thread<void*>( "connection", this.run_connection );
      #else
        try
        {
          Thread.create<void*>( this.run_connection, true );
        }
        catch( Error e )
        {
          stdout.printf( "Error while creating Thread" );
        }
      #endif
    }

    /**
     * This method read the data from the client
     */
    public void* run_connection( )
    {
      bool in_data;
      this.status = FILEDATA;
      while( this.status!= ERROR )
      {
        uint8[ ] buffer = new uint8[ buffer_size ];
        ssize_t len = 0;

        try
        {
          len = connection.receive ( buffer );
        }
        catch( Error e )
        {
          stdout.printf( "\nReading Buffer Faild: %s\n", e.message );
          this.status = ERROR;
          break;
        }

        if( len == 0 )
        {
          if( this.status < END )
          {
            this.status == ERROR;
          }
          else
          {
            stdout.printf( "\nFile was received!\n" );
          }
          break;
        }

        if( len == -1 )
        {
          stdout.printf( "\nFile could not be received!\n" );
          this.status = ERROR;
          break;
        }

        if( this.status == DATABLOCK )
        {
          in_data = true;
        }
        else
        {
          in_data = false;
        }

        handle_data( buffer, (int64)len );

        if( this.connection.is_closed( ) )
        {
          stdout.printf( "\nConnection is closed.\n" );
          if( this.status < END )
          {
            this.status == ERROR;
          }
          break;
        }
        else
        {
          try
          {
            if( this.status != DATABLOCK || !in_data )
            {
              this.connection.send( { 0 } );
            }
          }
          catch( Error e )
          {
            stdout.printf( "\nSending Faild: %s\n", e.message );
            this.status = ERROR;
          }
        }
      }
      return null;
    }

    /**
     * This method choose if the data should go to the file or to the interpreter
     * @param data The data from the client
     * @param len The length of data
     */
    public void handle_data( uint8[] data, int64 len )
    {
      if( this.status != DATABLOCK )
      {
        string temp_string = (string)data;
        string[ ] data_array = temp_string.split( "\n" );
        for( int64 i = 0; i < data_array.length; i ++ )
        {
          interprete( data_array[ i ].data, data_array[ i ].length );
        }
      }
      else
      {
        add_to_file( data, len );
      }
    }

    /**
     * This method add the data to the output file
     * @param data The data from the client
     * @param len The length of data
     */
    public void add_to_file( uint8[] data, int64 len )
    {
      uint8[] test = { };
      if( this.temp_filesize - len > 0 )
      {
        this.temp_filesize = this.temp_filesize - len;
        test = data[ 0 : len ];
        try
        {
          this.output.write( test );
        }
        catch( Error e )
        {
          stdout.printf( "\nWrite faild: %s\n", e.message );
        }
      }
      else
      {
        test = data[ 0 : this.temp_filesize ];
        try
        {
          this.output.write( test );
        }
        catch( Error e )
        {
          stdout.printf( "\nWrite faild: %s\n", e.message );
        }
        this.output.flush( );
        this.output = null;
        this.temp_filesize = this.temp_filesize - len;
        this.status = END;
      }

      float pro;
      pro = (float)( 100.0 - ( temp_filesize * 100.0 ) / (float)filesize );
      stdout.printf( "<" );
      for( int i = 0; i < 50; i ++ )
      {
        if( (int)( pro / 2 ) < i )
        {
          stdout.printf( " " );
        }
        else
        {
          stdout.printf( "-" );
        }
      }
      stdout.printf( "> %f %\r", pro );
    }

    /**
     * This method interpret the data and set the variables
     * @param data The data from the client
     * @param len The length of data
     */
    public void interprete( uint8[] data, int64 len )
    {
      uint64 first_symbol = data[ 0 ];
      switch ( first_symbol ) {

        /* Daemon commands */
        /* 01 - Print any waiting jobs */
        case 0x1:
          break;


        case 0x2:
          buffer_string = { };
          bool is_prq_name = true;
          for( int64 i = 1; i < len ; i ++ )
          {
            if( data[ i ] == ' ' )
            {
              is_prq_name = false;
            }
            buffer_string += data[ i ];
          }
          buffer_string += 0;
          if( is_prq_name )
          {
            /* Receive a printer job */
            this.prq_name = (string)buffer_string;
            stdout.printf( "\nPRQ - Name: %s\n", this.prq_name );
          }
          else
          {
            /* Receive control file */
          }
          break;

        /* 03 - Send queue state (short) */
        case 0x3:
          this.status = DATABLOCK;
          buffer_string = { };
          for( int64 i = 1; data[ i ] != ' '; i ++ )
          {
            buffer_string += data[ i ];
          }
          buffer_string += 0;
          filesize = int64.parse( (string)buffer_string );
          stdout.printf( "Filesize: %d\n", (int)filesize );
          temp_filesize = filesize;
          save_name = OpenDMLib.get_temp_file( );
          this.output = OpenDMLib.IO.open( save_name, "wb" );

          stdout.printf( "New Data File \n" );
          break;

        /* 04 - Send queue state (long) */
        case 0x4:
          break;

        /* 05 - Remove jobs */
        case 0x5:
          break;

        /* Control file lines */

        /* C - Class for banner page */
        case 'C':
          class_name = (string)data[ 1:len ];
          stdout.printf( "Class name: %s\n", class_name );
          break;

        /* H - Host name */
        case 'H':
          hostname = (string)data[ 1:len ];
          stdout.printf( "\nHostname: %s\n", hostname );
          break;

        /* I - Indent Printing */
        case 'I':
          buffer_string = { };
          for( int64 i = 1; data[ i ] != ' '; i ++ )
          {
            buffer_string += data[ i ];
          }
          buffer_string += 0;
          indenting_count = int64.parse( (string)buffer_string );
          stdout.printf( "indenting_count: %llu\n", indenting_count );
          break;

        /* J - Job name for banner page */
        case 'J':
          job_name = (string)data[ 1:len ];
          stdout.printf( "\nJob name: %s\n", job_name );
          break;

        /* L - Print banner page */
        case 'L':
          break;

        /* M - Mail When Printed */
        case 'M':
          break;

        /* N - Name of source file */
        case 'N':
          filename = (string)data[ 1:len ];
          stdout.printf( "\nFilename: %s\n", filename );
          break;

        /* P - User identification */
        case 'P':
          user_identification = (string)data[ 1:len ];
          stdout.printf( "\nUser Identification: %s\n", user_identification );
          break;

        /* S - Symbolic link data */
        case 'S':
          break;

        /* T - Title for pr */
        case 'T':
          title_text= (string)data[ 1:len ];
          stdout.printf( "\nTitle Text: %s\n", title_text );
          break;

        /* U - Unlink data file */
        case 'U':
          break;

        /* W - Width of output */
        case 'W':
          break;

        /* 1 - troff R font */
        case '1':
          break;

        /* 2 - troff I font */
        case '2':
          break;

        /* 3 - troff B font */
        case '3':
          break;

        /* 4 - troff S font */
        case '4':
          break;

        /* c - Plot CIF file */
        case 'c':
          break;

        /* d - Print DVI file */
        case 'd':
          break;

        /* f - Print formatted file */
        case 'f':
          break;

        /* g - Plot file */
        case 'g':
          break;

        /* l - Print file leaving control characters */
        case 'l':
          break;

        /* n - Print ditroff output file */
        case 'n':
          break;

        /* o - Print Postscript output file */
        case 'o':
          break;

        /* p - Print file with 'pr' format */
        case 'p':
          buffer_string = { };
          for( int64 i = 1; data[ i ] != ' '; i ++ )
          {
            buffer_string += data[ i ];
          }
          buffer_string += 0;
          print_file_with_pr = (string)buffer_string;
          stdout.printf( "p: %s\n", print_file_with_pr );
          break;

        /* r - File to print with FORTRAN carriage control */
        case 'r':
          break;

        /* t - Print troff output file */
        case 't':
          break;

        /* v - Print raster file */
        case 'v':
          break;

        case 0x00:
          break;

        default:
          stdout.printf( "First Element: %02x (%c)\n", data[ 0 ], data[ 0 ] );
          stdout.printf( "Unknown Code: %s\n", (string)data );
          break;
      }
    }
  }
}
/* PREPROCESSED */
