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

public class ExportOrgMode : Export {

  /* Constructor */
  public ExportOrgMode() {
    base( "org-mode", _( "Org-Mode" ), { ".org" }, true, false );
  }

  /* Exports the given drawing area to the file of the given name */
  public override bool export( string fname, DrawArea da ) {
    var  file   = File.new_for_path( fname );
    bool retval = true;
    try {
      var os = file.replace( null, false, FileCreateFlags.NONE );
      export_top_nodes( os, da );
    } catch( Error e ) {
      retval = false;
    }
    return( retval );
  }

  /* Draws each of the top-level nodes */
  private void export_top_nodes( FileOutputStream os, DrawArea da ) {

    try {

      var nodes = da.get_nodes();
      for( int i=0; i<nodes.length; i++ ) {
        string title = "* " + nodes.index( i ).name.text.text + "\n\n";
        os.write( title.data );
        if( nodes.index( i ).note != "" ) {
          string note = "  " + nodes.index( i ).note.replace( "\n", "\n  " );
          os.write( note.data );
        }
        var children = nodes.index( i ).children();
        for( int j=0; j<children.length; j++ ) {
          export_node( os, children.index( j ) );
        }
      }

    } catch( Error e ) {
      // Handle the error
    }

  }

  /* Draws the given node and its children to the output stream */
  private void export_node( FileOutputStream os, Node node, string prefix = "  " ) {

    try {

      string title = prefix + "* ";

      if( node.is_task() ) {
        if( node.is_task_done() ) {
          title += "[x] ";
        } else {
          title += "[ ] ";
        }
      }

      title += node.name.text.text.replace( "\n", prefix + " " ) + "\n";

      os.write( title.data );

      if( node.note != "" ) {
        string note = prefix + "  " + node.note.replace( "\n", "\n" + prefix + "  " ) + "\n";
        os.write( note.data );
      }

      os.write( "\n".data );

      var children = node.children();
      for( int i=0; i<children.length; i++ ) {
        export_node( os, children.index( i ), prefix + "  " );
      }

    } catch( Error e ) {
      // Handle error
    }

  }

}
