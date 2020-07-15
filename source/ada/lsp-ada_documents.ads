------------------------------------------------------------------------------
--                         Language Server Protocol                         --
--                                                                          --
--                     Copyright (C) 2018-2019, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------
--
--  This package provides an Ada document abstraction.

with Ada.Containers.Ordered_Maps;
with Ada.Containers.Vectors;

with LSP.Messages;
with LSP.Types;

with Libadalang.Analysis;
with Libadalang.Common;

limited with LSP.Ada_Contexts;
with LSP.Ada_Completion_Sets;

with GNATCOLL.Traces;
with GNATCOLL.VFS;

with Pp.Command_Lines;

with VSS.Strings;

package LSP.Ada_Documents is

   MAX_NB_DIAGNOSTICS : constant := 2;

   type Document (Trace : GNATCOLL.Traces.Trace_Handle) is
     tagged limited private;
   --  An Ada document (file).

   type Document_Access is access all LSP.Ada_Documents.Document
     with Storage_Size => 0;

   procedure Initialize
     (Self : in out Document;
      URI  : LSP.Messages.DocumentUri;
      Text : LSP.Types.LSP_String);
   --  Create a new document from a TextDocumentItem. Use LAL as libadalang
   --  context to parse text of the document.

   -----------------------
   -- Contents handling --
   -----------------------

   function URI (Self : Document) return LSP.Messages.DocumentUri;
   --  Return the URI associated with Self

   function Text (Self : Document) return LSP.Types.LSP_String;
   --  Return the text associated with Self

   function Get_Text_At
     (Self      : Document;
      Start_Pos : LSP.Messages.Position;
      End_Pos   : LSP.Messages.Position) return String;
   --  Return the text in the specified range.

   procedure Apply_Changes
     (Self    : aliased in out Document;
      Version : LSP.Messages.Nullable_Number;
      Vector  : LSP.Messages.TextDocumentContentChangeEvent_Vector);
   --  Modify document according to event vector provided by LSP client.

   function Versioned_Identifier
     (Self : Document) return LSP.Messages.VersionedTextDocumentIdentifier;

   --------------
   -- Requests --
   --------------

   --  These requests are meaningful within a document/context pair

   procedure Get_Errors
     (Self    : Document;
      Context : LSP.Ada_Contexts.Context;
      Errors  : out LSP.Messages.Diagnostic_Vector);
   --  Get errors found during document parsing.

   function Has_Diagnostics
     (Self    : Document;
      Context : LSP.Ada_Contexts.Context)
      return Boolean;
   --  Returns True when errors found during document parsing.

   procedure Get_Symbols
     (Self    : Document;
      Context : LSP.Ada_Contexts.Context;
      Result  : out LSP.Messages.Symbol_Vector);
   --  Populate Result with symbols from the document.

   procedure Get_Symbol_Hierarchy
     (Self    : Document;
      Context : LSP.Ada_Contexts.Context;
      Result  : out LSP.Messages.Symbol_Vector);
   --  Populate Result with a symbol hierarchy from the document.

   function Get_Node_At
     (Self     : Document;
      Context  : LSP.Ada_Contexts.Context;
      Position : LSP.Messages.Position)
      return Libadalang.Analysis.Ada_Node;
   --  Get Libadalang Node for given position in the document.

   function Get_Word_At
     (Self     : Document;
      Context  : LSP.Ada_Contexts.Context;
      Position : LSP.Messages.Position)
      return LSP.Types.LSP_String;
   --  Get an identifier at given position in the document or an empty string.

   procedure Get_Completions_At
     (Self                     : Document;
      Context                  : LSP.Ada_Contexts.Context;
      Position                 : LSP.Messages.Position;
      Snippets_Enabled         : Boolean;
      Named_Notation_Threshold : Natural;
      Result                   : out Ada_Completion_Sets.Completion_Result);
   --  Populate Result with completions for given position in the document.
   --  When Snippets_Enabled is True, subprogram completion items are computed
   --  as snippets that list all the subprogram's formal parameters.
   --  Named_Notation_Threshold defines the number of parameters / components
   --  at which point named notation is used for subprogram/aggregate
   --  completion snippets.

   procedure Get_Any_Symbol_Completion
     (Self    : in out Document;
      Context : LSP.Ada_Contexts.Context;
      Prefix  : VSS.Strings.Virtual_String;
      Limit   : Ada.Containers.Count_Type;
      Result  : in out LSP.Ada_Completion_Sets.Completion_Map);
   --  See Contests.Get_Any_Symbol_Completion

   procedure Get_Folding_Blocks
     (Self       : Document;
      Context    : LSP.Ada_Contexts.Context;
      Lines_Only : Boolean;
      Comments   : Boolean;
      Result     : out LSP.Messages.FoldingRange_Vector);
   --  Populate Result with code folding blocks in the document. If Lines_Only
   --  is True does not return characters positions in lines.

   function Formatting
     (Self     : Document;
      Context  : LSP.Ada_Contexts.Context;
      Span     : LSP.Messages.Span;
      Cmd      : Pp.Command_Lines.Cmd_Line;
      Edit     : out LSP.Messages.TextEdit_Vector)
      return Boolean;
   --  Format document or its part defined in Span

   procedure Get_Imported_Units
     (Self          : Document;
      Context       : LSP.Ada_Contexts.Context;
      Project_Path  : GNATCOLL.VFS.Virtual_File;
      Show_Implicit : Boolean;
      Result        : out LSP.Messages.ALS_Unit_Description_Vector);
   --  Return all the units that import the document's unit.
   --  If Show_Implicit is True, units that import implicitly on the document's
   --  unit are also returned.

   procedure Get_Importing_Units
     (Self          : Document;
      Context       : LSP.Ada_Contexts.Context;
      Project_Path  : GNATCOLL.VFS.Virtual_File;
      Show_Implicit : Boolean;
      Result        : out LSP.Messages.ALS_Unit_Description_Vector);
   --  Return the units that import the document's unit among the given list.
   --  If Show_Implicit is True, units that depend on the document's unit in
   --  an implicit way will also be returned.

   -----------------------
   -- Document_Provider --
   -----------------------

   type Document_Provider is limited interface;
   type Document_Provider_Access is access all Document_Provider'Class;
   --  A Document_Provider is an object that contains documents and
   --  is able to retrieve a document from its given URI.

   function Get_Open_Document
     (Self  : access Document_Provider;
      URI   : LSP.Messages.DocumentUri;
      Force : Boolean := False)
      return Document_Access is abstract;
   --  Return the open document for the given URI.
   --  If the document is not opened, then if Force a new document
   --  will be created and must be freed by the user else null will be
   --  returned.

private

   package Line_To_Index_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Positive,
      "="          => "=");
   use Line_To_Index_Vectors;

   package Symbol_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => VSS.Strings.Virtual_String,
      Element_Type => Libadalang.Common.Token_Reference,
      "<"          => VSS.Strings."<",
      "="          => Libadalang.Common."=");

   type Document (Trace : GNATCOLL.Traces.Trace_Handle) is tagged limited
   record
      URI  : LSP.Messages.DocumentUri;

      Version : LSP.Types.LSP_Number := 1;
      --  Document version

      Text : LSP.Types.LSP_String;
      --  The text of the document

      Line_To_Index : Vector;
      --  Within text, an array associating a line number (starting at 0) to
      --  the offset of the first character of that line in Text.
      --  This serves as cache to be able to modify text ranges in Text
      --  given in line/column coordinates without having to scan the whole
      --  text from the beginning.

      Symbol_Cache : Symbol_Maps.Map;
      --  Cache of all defining name symbol of the document.
   end record;

   procedure Diff
     (Self     : Document;
      New_Text : LSP.Types.LSP_String;
      Old_Span : LSP.Messages.Span := LSP.Messages.Empty_Span;
      New_Span : LSP.Messages.Span := LSP.Messages.Empty_Span;
      Edit     : out LSP.Messages.TextEdit_Vector);
   --  Create a diff between document Text and New_Text and return Text_Edit
   --  based on Needleman-Wunsch algorithm
   --  Old_Span and New_Span are used when we need to compare certain
   --  old/new lines instead of whole buffers

   function URI (Self : Document) return LSP.Messages.DocumentUri is
     (Self.URI);
   function Text (Self : Document) return LSP.Types.LSP_String is (Self.Text);

end LSP.Ada_Documents;
