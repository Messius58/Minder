 /*
* Copyright (c) 2018 (https://github.com/phase1geo/Minder)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

using Gtk;
using Gdk;
using GLib;

public class Minder : Granite.Application {

  private const string INTERFACE_SCHEMA = "org.gnome.desktop.interface";

  private static bool          show_version = false;
  private static string?       open_file    = null;
  private static bool          new_file     = false;
  private static bool          testing      = false;
  private        MainWindow    appwin;
  private        GLib.Settings iface_settings;

  public  static GLib.Settings settings;
  public  static string        version = "1.15.0";

  public Minder () {

    Object( application_id: "com.github.phase1geo.minder", flags: ApplicationFlags.HANDLES_OPEN );

    startup.connect( start_application );
    open.connect( open_files );

  }

  /* First method called in the startup process */
  private void start_application() {

    /* Initialize the settings */
    settings = new GLib.Settings( "com.github.phase1geo.minder" );

    /* Add the application-specific icons */
    weak IconTheme default_theme = IconTheme.get_default();
    default_theme.add_resource_path( "/com/github/phase1geo/minder" );

    /* Create the main window */
    appwin = new MainWindow( this, settings );

    /* Load the tab data */
    appwin.load_tab_state();

    /* Handle any changes to the position of the window */
    appwin.configure_event.connect(() => {
      int root_x, root_y;
      int size_w, size_h;
      appwin.get_position( out root_x, out root_y );
      appwin.get_size( out size_w, out size_h );
      settings.set_int( "window-x", root_x );
      settings.set_int( "window-y", root_y );
      settings.set_int( "window-w", size_w );
      settings.set_int( "window-h", size_h );
      return( false );
    });

    /* Initialize desktop interface settings */
    string[] names = {"font-name", "text-scaling-factor"};
    iface_settings = new GLib.Settings( INTERFACE_SCHEMA );
    foreach( string name in names ) {
      iface_settings.changed[name].connect(() => {
        Timeout.add( 500, () => {
          appwin.update_node_sizes();
          return( Source.REMOVE );
        });
      });
    }

  }

  /* Called whenever files need to be opened */
  private void open_files( File[] files, string hint ) {
    hold();
    foreach( File open_file in files ) {
      var file = open_file.get_path();
      if( !appwin.open_file( file ) ) {
        stdout.printf( _( "ERROR:  Unable to open file '%s'\n" ), file );
      }
    }
    Gtk.main();
    release();
  }

  /* Called if we have no files to open */
  protected override void activate() {
    hold();
    if( new_file ) {
      appwin.do_new_file();
    }
    Gtk.main();
    release();
  }

  /* Parse the command-line arguments */
  private void parse_arguments( ref unowned string[] args ) {

    var context = new OptionContext( "- Minder Options" );
    var options = new OptionEntry[6];
    var export  = false;
    var export_format = "png";

    /* Create the command-line options */
    options[0] = {"version", 0, 0, OptionArg.NONE, ref show_version, _( "Display version number" ), null};
    options[1] = {"new", 'n', 0, OptionArg.NONE, ref new_file, _( "Starts Minder with a new file" ), null};
    options[2] = {"run-tests", 0, 0, OptionArg.NONE, ref testing, _( "Run testing" ), null};
    options[3] = {"export", 0, 0, OptionArg.NONE, ref export, _( "Export mindmap" ), null};
    options[4] = {"format", 0, 0, OptionArg.STRING, ref export_format, _(
    "Format to export as (only used when --export is used)" ), "FORMAT"};
    options[5] = {null};

    /* Parse the arguments */
    try {
      context.set_help_enabled( true );
      context.add_main_entries( options, null );
      context.parse( ref args );
    } catch( OptionError e ) {
      stdout.printf( _( "ERROR: %s\n" ), e.message );
      stdout.printf( _( "Run '%s --help' to see valid options\n" ), args[0] );
      Process.exit( 1 );
    }

    /* If the version was specified, output it and then exit */
    if( show_version ) {
      stdout.printf( version + "\n" );
      Process.exit( 0 );
    }

    /* If we are tasked to export from the command-line, let's just do it and exit */
    if( export ) {
      int retval = 1;
      if( args.length >= 3 ) {
        retval = export_as( export_format, args[args.length-2], args[args.length-1] ) ? 0 : 1;
      } else {
        stderr.printf( _( "ERROR: Export is missing Minder input file and/or export output file" ) + "\n" );
      }
      Process.exit( retval );
    }

    /* If we see files on the command-line */
    if( args.length >= 2 ) {
      open_file = args[1];
    }

  }

  /* Exports the given mindmap from the command-line */
  private bool export_as( string format, string infile, string outfile ) {

    var exports = new Exports( false );

    for( int i=0; i<exports.length(); i++ ) {
      var export = exports.index( i );
      if( export.name == format ) {
        var settings    = new GLib.Settings( "com.github.phase1geo.minder" );
        var win         = new MainWindow( this, settings );
        var accel_group = new Gtk.AccelGroup();
        var da          = new DrawArea( win, settings, accel_group );

        da.get_doc().load_filename( infile, false );
        if( da.get_doc().load() ) {
          return( export.export( outfile, da ) );
        } else {
          stderr.printf( _( "ERROR:  Unable to load Minder input file" ) + "\n" );
          return( false );
        }
      }
    }

    return( false );

  }

  /* Main routine which gets everything started */
  public static int main( string[] args ) {

    var app = new Minder();
    app.parse_arguments( ref args );

    if( testing ) {
      Gtk.init( ref args );
      var testing = new App.Tests.Testing( args );
      Idle.add(() => {
        testing.run();
        Gtk.main_quit();
        return( false );
      });
      Gtk.main();
      return( 0 );
    } else {
      return( app.run( args ) );
    }

  }

}

