﻿IMPORT TextSearch.Common.Types;

EXPORT Layouts := MODULE
  // Document from outside source
  EXPORT DocumentIngest := RECORD
    Types.DocIdentifier     identifier;
    Types.SequenceKey       seqKey;
    Types.SlugLine          slugLine;
    UNICODE                 content;
  END;
  EXPORT DocumentNo := RECORD
    Types.DocNo id;
  END;
  EXPORT Document := RECORD(DocumentIngest)
    DocumentNo;
  END;
  // Posting Record, generated by parsing the documents.
  EXPORT RawPosting := RECORD
    Types.DocNo               id;
    Types.KWP                 kwp;
    Types.Position            start;
    Types.Position            stop;
    Types.Depth               depth;
    Types.TermLength          len;
    Types.TermLength          lenText;
    Types.KWP                 keywords;
    Types.TermType            typTerm;
    Types.DataType            typData;
    Types.Ordinal             preorder;    // position in tree
    Types.Ordinal             parentOrd;   // parent position
    Types.LetterPattern       lp;
    Types.TermString          tagName;
    Types.TermString          term;
    Types.TermString          tagValue;
    Types.PathString          pathString;
    Types.TermString          parentName;
  END;
END;