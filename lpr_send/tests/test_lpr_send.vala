using Testlib;

public class TestLprSend
{
  public static int main( string[] args )
  {
    /* filename is the testfile for the lpr sender */
    filename = "/home/documatrix/Dokumente/tests/LPRSenderPerl/10000_Seiten_Dominik.pdf";

    /* address is the address of remote server for the lpr sender */
    address = GLib.Environment.get_host_name( ).split( ".site" )[ 0 ];
    //address = "172.20.7.249";

    /* Directory prefix for the output file */
    queue = "dthold"; 

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

    ts_send.add(
      new GLib.TestCase(
        "test_f_send_configuration",
        TestLprSend.default_setup,
        TestLprSend.test_send_f_send_configuration,
        TestLprSend.default_teardown
      )
    );

    ts_send.add(
      new GLib.TestCase(
        "test_f_send_file",
        TestLprSend.default_setup,
        TestLprSend.test_send_f_send_file,
        TestLprSend.default_teardown
      )
    );

    ts_lpr_send.add_suite( ts_send );
    GLib.Test.run( );
    return 0;
  }

  /**
   * filename is the testfile for the lpr sender
   */
  public static string filename = null;

  /**
   * address is the address of remote server for the lpr sender
   */
  public static string address = null;

  /**
   * queue is the directory prefix for the output file
   */
  public static  string queue = null;

  /**
   * This testcase tests constructor of the lpr_send
   */
  public static void test_send_n( )
  {
    try
    {
      LprLib.LprSend send = new LprLib.LprSend( address, filename );
      assert( send != null );

      send.close( );

      send = new LprLib.LprSend( "12345", filename );
      send.close( );
    }
    catch( Error e )
    {
      assert( e.message != null );
      print( "\n\nError: " + e.message + "\n" );
    }
  }

  /**
   * This testcase tests constructor of the lpr_send
   */
  public static void test_send_f_send_configuration( )
  {
    try
    {
      LprLib.LprSend send = new LprLib.LprSend( address,filename );
      send.send_configuration( queue );
      assert( send != null );
      send.close( );
    }
    catch( Error e )
    {
      assert( e.message != null );
      print( "\n\nError: " + e.message + "\n" );
    }
  }

  /**
   * This testcase tests constructor of the lpr_send
   */
  public static void test_send_f_send_file( )
  {
    try
    {
      LprLib.LprSend send = new LprLib.LprSend( address,filename );
      send.send_configuration( queue );
      assert( send != null );
      send.send_file( );
      send.close( );
      assert( send != null );
    }
    catch( Error e )
    {
      assert( e.message != null );
      print( "\n\nError: " + e.message + "\n" );
    }
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
