using DMLib;

namespace LprDaemon
{
  public class Server : GLib.Object
  {
    private Connection[ ] con;

    public Server( uint16 port = 515 , string? ip_address = null )
    {
      InetAddress address = new InetAddress.loopback( SocketFamily.IPV4 );

      if( ip_address == null )
      {
        var resolver = Resolver.get_default( );
        var addresses = resolver.lookup_by_name( "linux-88qt" , null );
        address = addresses.nth_data ( 0 );
        stdout.printf( "\n\nIhre IP-Adresse: %s\n", address.to_string( ) );
      }
      else
      {
        address = new InetAddress.from_string( ip_address );
      }

      InetSocketAddress inetaddress = new InetSocketAddress( address, port );

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

    public void listen( Socket socket )
    {
       #if GLIB_2_32
        new Thread<void*>( "connection", ( ) =>
        {
          while( true )
          {
            stdout.printf( "Waiting for new Connection....\n" );
            Socket connection_socket = socket.accept( );
            Connection test = new Connection( con.length + 1, connection_socket );
            con += test;
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
              Connection test = new Connection( con.length + 1, connection_socket );
              con += test;
            }
          }, true );
        }
        catch( Error e )
        {
          stdout.printf( "Error while creating Thread" );
        }
      #endif
    }

    public Connection[ ] get_connections( )
    {
      return con;
    }

    public void del_connection( uint64 connection )
    {
      Connection[ ] buffer_conections = con;
      con = null;
      for( int i = 0; i < con.length; i ++ )
      {
        if( i != connection )
        {
          con += buffer_conections[ i ];
        }
      }
    }

  }
  /**
   * This class includes all methods to read a PS-File
   * It adds the pages and gets the position of the areas
   */
  public class Connection : GLib.Object
  {
    /* man befindet sich im Header */
    public static const int16 HEADER = 0;

    /* man befindet sich im Preamble */
    public static const int16 FILEDATA = 1;

    /* man befindet sich im Page-Bereich */
    public static const int16 DATABLOCK = 2;

    /* man befindet sich im Trailer */
    public static const int16 END = 3;

    /* man befindet sich am Ende des Files */
    public static const uint8 ERROR = -1;

    /* buffer uint8 array */
    private uint8[] buffer_string;

    /* the  */
    private int64 temp_filesize = 0;

    /* connection ID */
    public int64 connection_id;

    /* connection */
    public Socket connection;

    /* Hostname */
    public string hostname = null;

    /* Filename */
    public string filename = null;

    /* User Identification */
    public string user_identification = null;

    /* Job name */
    public string job_name = null;

    /* Job name */
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

    public int16 status = 0;

    public string print_file_with_pr = null;

    public Connection( int64 id, Socket socket, int64 buffer_size = 8192 )
    {
      this.connection_id = id;
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

    public void* run_connection( )
    {
      bool in_data;
      bool outnow = false;
      uint8[] helper = { };
      this.status = FILEDATA;
      while( true )
      {
        uint8[ ] buffer = new uint8[ buffer_size ];
        ssize_t len = 0;
        if( status < DATABLOCK )
        {
          while( !outnow )
          {
            buffer = { };
            try
            {
              len = connection.receive ( buffer );
              if( len == 0 )
              {
                stdout.printf( "Senden wurde erfolgreich beendet!\n" );
                this.status = END;
                break;
              }
              if( len == -1 )
              {
                stdout.printf( "Senden fehlgeschlagen!\n" );
                this.status = ERROR;
                break;
              }
            }
            catch( Error e )
            {
              stdout.printf( "Reading Buffer Faild: %s\n", e.message );
              this.status = ERROR;
              break;
            }
            for( int i = 0; i < len; i ++ )
            {
              if( buffer[ i ] == '\n' )
              {
                outnow = true;
                break;
              }
              else
              {
                helper += buffer[ i ];
              }
            }
          }
        }
        else
        {
          try
          {
            len = connection.receive ( buffer );
          }
          catch( Error e )
          {
            stdout.printf( "Reading Buffer Faild: %s\n", e.message );
            this.status = ERROR;
            break;
          }
        }

        stdout.printf( "HElPER: %s", (string)helper);

        if( this.status == DATABLOCK )
        {
          in_data = true;
        }
        else
        {
          in_data = false;
        }

        /*if( status != DATABLOCK )
        {
          stdout.printf( "\n\ndata: %s %d\n\n", (string)buffer, (int)len );
        }*/

        handle_data( helper, (int64)len );
        if( this.connection.is_closed( ) )
        {
          stdout.printf( "Verbindung wurde beendet.\n" );
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
            else
            {
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
              stdout.printf( "> %f %\n", pro );
            }

          }
          catch( Error e )
          {
            stdout.printf( "Sending Faild: %s\n", e.message );
            this.status = ERROR;
          }
        }
      }
      return null;
    }

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

    public void add_to_file( uint8[] data, int64 len )
    {
      uint8[] test = { };
      if( this.temp_filesize - len > 0 )
      {
        this.temp_filesize = this.temp_filesize - len;
        test = data[ 0 : len ];
        this.output.write( test );
      }
      else
      {
        test = data[ 0 : this.temp_filesize ];
        this.output.write( test );
        this.output.flush( );
        this.status = END;
        stdout.printf( "\n\n\nENDE\n\n\n" );
      }
    }

    public void interprete( uint8[] data, int64 len )
    {
      uint64 first_symbol = data[ 0 ];
      switch ( first_symbol ) {

        /* Daemon commands */
        case 0x1:
          break;

        case 0x2:
          buffer_string = { };
          for( int64 i = 1; i < len ; i ++ )
          {
            buffer_string += data[ i ];
          }
          buffer_string += 0;
          stdout.printf( "\nPRQ - Name: %s\n", (string)buffer_string );
          break;

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
          if( filename != null )
          {
            this.output = DMLib.IO.open( filename + "_" + connection_id.to_string( ), "wb" );
          }
          else
          {
            this.output = DMLib.IO.open( "New_File", "wb" );
          }
          stdout.printf( "New Data File \n" );
          break;

        case 0x4:
          break;

        case 0x5:
          break;

        /* Control file lines */
        case 'C':
          buffer_string = { };
          for( int64 i = 1; data[ i ] != ' '; i ++ )
          {
            buffer_string += data[ i ];
          }
          buffer_string += 0;
          class_name = (string)buffer_string;
          stdout.printf( "Class name: %s\n", class_name );
          break;

        case 'H':
          buffer_string = { };
          for( int64 i = 1; i < len ; i ++ )
          {
            buffer_string += data[ i ];
          }

          buffer_string += 0;
          hostname = (string)buffer_string;
          stdout.printf( "\nHostname: %s\n", hostname );
          break;

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

        case 'J':
          buffer_string = { };
          for( int64 i = 1; i < len ; i ++ )
          {
            buffer_string += data[ i ];
          }

          buffer_string += 0;
          job_name = (string)buffer_string;
          stdout.printf( "\nJob name: %s\n", job_name );
          break;

        case 'L':
          break;

        case 'M':
          break;

        case 'N':
          buffer_string = { };
          for( int64 i = 1; i < len ; i ++ )
          {
            buffer_string += data[ i ];
          }

          buffer_string += 0;
          filename = (string)buffer_string;
          stdout.printf( "\nFilename: %s ( %d )\n", filename, filename.length );
          break;

        case 'P':
          buffer_string = { };
          for( int64 i = 1; i < len ; i ++ )
          {
            buffer_string += data[ i ];
          }

          buffer_string += 0;
          user_identification = (string)buffer_string;
          stdout.printf( "\nUser Identification: %s\n", user_identification );
          break;

        case 'S':
          break;

        case 'T':
          buffer_string = { };
          for( int64 i = 1; i < len ; i ++ )
          {
            buffer_string += data[ i ];
          }

          buffer_string += 0;
          title_text= (string)buffer_string;
          stdout.printf( "\nTitle Text: %s\n", title_text );
          break;

        case 'U':
          break;

        case 'W':
          break;

        case '1':
          break;

        case '2':
          break;

        case '3':
          break;

        case '4':
          break;

        case 'c':
          break;

        case 'd':
          break;

        case 'f':
          break;

        case 'g':
          break;

        case 'l':
          break;

        case 'n':
          break;

        case 'o':
          break;

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

        case 'r':
          break;

        case 't':
          break;

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
