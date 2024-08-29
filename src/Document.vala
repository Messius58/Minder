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

using Cairo;
using Gtk;
using GLib;

public class Document : Object {

  private DrawArea      _da;
  private string        _filename;
  private bool          _from_user;  // Set to true if _filename was set by the user
  private ImageManager  _image_manager;

  /* Properties */
  public string filename {
    set {
      if( _filename != value ) {
        if( !_from_user ) {
          FileUtils.unlink( _filename );
        }
        _filename  = value;
        _from_user = true;
      }
    }
    get {
      return( _filename );
    }
  }
  public string label {
    owned get {
      return( GLib.Path.get_basename( _filename ) );
    }
  }
  public bool save_needed { private set; get; default = false; }

  /* Default constructor */
  public Document( DrawArea da, string directory = "") {

    _da = da;

    /* Create the temporary file */
    var dir = directory;
    if(dir == "") {
      dir = GLib.Path.build_filename( Environment.get_user_data_dir(), "minder" );
    }
    if( DirUtils.create_with_parents( dir, 0775 ) == 0 ) {
      int i = 1;
      do {
        _filename = GLib.Path.build_filename( dir, _( "unnamed" ) + "%d.minder".printf( i++ ) );
      } while( GLib.FileUtils.test( _filename, FileTest.EXISTS ) );
      _from_user = false;
    }

    /* Create the image manager */
    _image_manager = new ImageManager();

    /* Listen for any changes from the canvas */
    _da.changed.connect( canvas_changed );

  }

  /* Called whenever the canvas changes such that a save will be needed */
  private void canvas_changed() {
    save_needed = true;
    auto_save();
  }

  /* Called when a document filename is loaded from the tab state file */
  public void load_filename( string fname, bool saved ) {
    filename   = fname;
    _from_user = saved;
  }

  /* Returns true if the stored filename came from the user */
  public bool is_saved() {
    return( _from_user );
  }

  /* Opens the given filename */
  public bool load() {
    Xml.Doc* doc = Xml.Parser.read_file( filename, null, Xml.ParserOption.HUGE );
    if( doc == null ) {
      return( false );
    }
    _da.load( doc->get_root_element() );
    delete doc;
    return( true );
  }

  /* Saves the given node information to the specified file */
  public bool save() {
    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "minder" );
    root->set_prop( "version", Minder.version );
    doc->set_root_element( root );
    _da.save( root );
    doc->save_format_file( filename, 1 );
    delete doc;
    save_needed = false;
    return( true );
  }

  /* Deletes the given unnamed file when called */
  public bool remove() {
    if( !_from_user ) {
      FileUtils.unlink( _filename );
    }
    return( true );
  }

  /* Auto-saves the document */
  public void auto_save() {
    if( save_needed ) {
      save();
    }
  }

}
