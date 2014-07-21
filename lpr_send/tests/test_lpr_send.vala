using Testlib;

public class TestLprSend
{
  public static int main( string[] args )
  {
    GLib.Test.init( ref args );

    GLib.TestSuite ts_lpr_send = new GLib.TestSuite( "LPR-Send" );
    GLib.TestSuite.get_root( ).add_suite( ts_lpr_send );
    GLib.TestSuite ts_send = new GLib.TestSuite( "LprLip" );

    ts_send.add(
      new GLib.TestCase(
        "test_n",
        TestLprSend.default_setup,
        TestLprSend.test_send_n,
        TestLprSend.default_teardown
      )
    );

    ts_lpr_send.add_suite( ts_send );
    GLib.Test.run( );
    return 0;
  }

   /**
   * This testcase tests constructor of the lpr_send
   */
  public static void test_send_n( )
  {
      string filename = "/home/documatrix/Dokumente/tests/LPRSenderPerl/10000_Seiten_Dominik.pdf";
      string queue = "dthold";
      string address = GLib.Environment.get_host_name( ).split( ".site" )[ 0 ];

      print( address+"\n" );

      LprLib.LprSend send = new LprLib.LprSend(address,filename);
      send.send_configuration( queue );
      send.send_file();
      send.close();

      //filename = "/home/documatrix/Dokumente/tests/LPRSenderPerl/10000_Seiten_Dominik.ps";
      //send = new LprLib.LprSend(address,filename);
      //send.send_configuration( queue );
      //send.send_file();
      //send.close();
  }

  /**
   * This is the default setup method for the LprLib tests.
   * It will setup a DocuMatrix.Logger object and then invoke the default_setup method from Testlib.
   */
  public static void default_setup( )
  {
    DocuMatrix.log = new DocuMatrix.Logger( null );
    DocuMatrix.log.set_config( true, "../log/messages.mdb" );
    DocuMatrix.log.start_threaded( );
    Testlib.default_setup( );
  }

  /**
   * This is the default teardown method for the LprLib tests.
   * It will stop the DocuMatrix.Logger and then invoke the default_teardown method from Testlib.
   */
  public static void default_teardown( )
  {
    if ( DocuMatrix.log != null )
    {
      DocuMatrix.log.stop( );
    }
    Testlib.default_teardown( );
  }
}
