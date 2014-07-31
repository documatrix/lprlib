using Testlib;

public class TestLprDaemon
{
  public static int main( string[] args )
  {
    GLib.Test.init( ref args );

    GLib.TestSuite ts_lpr_daemon = new GLib.TestSuite( "LPR-Deamon" );
    GLib.TestSuite.get_root( ).add_suite( ts_lpr_daemon );
    GLib.TestSuite ts_server = new GLib.TestSuite( "Server" );

    ts_server.add(
      new GLib.TestCase(
        "test_n",
        TestLprDaemon.default_setup,
        TestLprDaemon.test_server_n,
        TestLprDaemon.default_teardown
      )
    );

    ts_lpr_daemon.add_suite( ts_server );
    GLib.Test.run( );
    return 0;
  }

   /**
   * his test case test the constructor of the server
   */
  public static void test_server_n( )
  {
    LprDaemon.Server server = new LprDaemon.Server( );
    while( true )
    {
      if( server.get_connections( ).length == 1 )
      {
        if( server.get_connections( )[ 0 ].status == 3 )
        {
          //break;
        }
      }
    }
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
