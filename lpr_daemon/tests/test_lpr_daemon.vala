using Testlib;

public class TestLprDaemon
{
  public static int main( string[] args )
  {
    GLib.Test.init( ref args );

    GLib.TestSuite ts_lpr_lib = new GLib.TestSuite( "LPR-Lib" );
    GLib.TestSuite.get_root( ).add_suite( ts_lpr_lib );
    GLib.TestSuite ts_lpr_daemon = new GLib.TestSuite( "Daemon" );
    GLib.TestSuite ts_connection = new GLib.TestSuite( "Connection" );

    ts_lpr_daemon.add(
      new GLib.TestCase(
        "test_n",
        TestLprDaemon.default_setup,
        TestLprDaemon.test_lpr_daemon_n,
        TestLprDaemon.default_teardown
      )
    );
    ts_connection.add(
      new GLib.TestCase(
        "test_n",
        TestLprDaemon.default_setup,
        TestLprDaemon.test_connection_n,
        TestLprDaemon.default_teardown
      )
    );
    ts_connection.add(
      new GLib.TestCase(
       "test_f_interprete",
        TestLprDaemon.default_setup,
        TestLprDaemon.test_f_interprete,
        TestLprDaemon.default_teardown
      )
    );
    ts_connection.add(
      new GLib.TestCase(
       "test_f_handle_data",
        TestLprDaemon.default_setup,
        TestLprDaemon.test_f_handle_data,
        TestLprDaemon.default_teardown
      )
    );
    ts_connection.add(
      new GLib.TestCase(
       "test_f_add_to_file",
        TestLprDaemon.default_setup,
        TestLprDaemon.test_f_add_to_file,
        TestLprDaemon.default_teardown
      )
    );
    ts_lpr_lib.add_suite( ts_lpr_daemon );
    ts_lpr_lib.add_suite( ts_connection );
    GLib.Test.run( );
    return 0;
  }

   /**
   * This test case test the constructor of the server
   */
  public static void test_lpr_daemon_n( )
  {
    LprLib.LprDaemon server = new LprLib.LprDaemon( );
    assert( server != null );
  }

   /**
   * This test case test the constructor of the server
   */
  public static void test_connection_n( )
  {
    Socket socket = new Socket( SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.TCP );
    LprLib.Connection connection = new LprLib.Connection( socket );
    assert( connection != null );
  }

   /**
   * This test case test the constructor of the server
   */
  public static void test_f_interprete( )
  {
    Socket socket = new Socket( SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.TCP );
    LprLib.Connection connection = new LprLib.Connection( socket );
    assert( connection != null );
    connection.interprete( "%cdthold".printf( 0x02 ).data, 7 );
    stdout.printf( "\n\n\n\n\n\ntest: %s\n\n\n\n\n\n", connection.prq_name );
    connection.interprete( "%c1234 dfA000linux.oyd2.site".printf( 0x03 ).data, 27 );
    assert( connection.prq_name == "dthold" );
    assert( connection.filesize == 1234 );
    assert( connection.status == connection.DATABLOCK );
  }

   /**
   * This test case test the constructor of the server
   */
  public static void test_f_handle_data( )
  {
    string filename = Testlib.create_temp_file( "" );
    Socket socket = new Socket( SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.TCP );
    LprLib.Connection connection = new LprLib.Connection( socket );
    assert( connection != null );
    connection.handle_data( ( "%c" + filename ).printf( 0x02 ).data, 7 );
    connection.handle_data( "%c12 dfA000linux.oyd2.site".printf( 0x03 ).data, 27 );
    connection.handle_data( "Hallo ".data, 6 );
    assert( connection.status == connection.DATABLOCK );
    connection.handle_data( "test !".data, 6 );
    assert( connection.filesize == 12 );
    assert( connection.status == connection.END );

  }

   /**
   * This test case test the constructor of the server
   */
  public static void test_f_add_to_file( )
  {
    string filename = Testlib.create_temp_file( "" );
    string text = "Hallo\nDas ist test";
    Socket socket = new Socket( SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.TCP );
    LprLib.Connection connection = new LprLib.Connection( socket );
    assert( connection != null );
    connection.handle_data( ( "N" + filename ).data, filename.length + 1 );
    connection.handle_data( "%c18 dfA000linux.oyd2.site".printf( 0x03 ).data, 27 );
    assert( connection.status == connection.DATABLOCK );

    connection.handle_data( text.data, 18 );

    FileStream stream = FileStream.open( filename, "rb" );

    uint8[] filedata = new uint8[ 18 ];
    try
    {
      stream.read( filedata );
      GLib.assert( true );
    }
    catch( Error e )
    {
      stdout.printf( "\n\n\nFaild: %s\n", e.message );
      GLib.assert( false );
    }

    assert( (string)filedata == text );
    assert( connection.status == connection.END );

  }



  /**
   * This is the default setup method for the LPR-Daemon tests.
   * It will setup a DMLogger.Logger object and then invoke the default_setup method from Testlib.
   */
  public static void default_setup( )
  {
    DMLogger.log = new DMLogger.Logger( null );
    DMLogger.log.set_config( true, "../log/messages.mdb" );
    DMLogger.log.start_threaded( );
    Testlib.default_setup( );
  }

  /**
   * This is the default teardown method for the LPR-Daemon tests.
   * It will stop the DMLogger.Logger and then invoke the default_teardown method from Testlib.
   */
  public static void default_teardown( )
  {
    if ( DMLogger.log != null )
    {
      DMLogger.log.stop( );
    }
    Testlib.default_teardown( );
  }
}
