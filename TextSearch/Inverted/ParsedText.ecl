﻿// Parse contents of the document
IMPORT TextSearch;
IMPORT TextSearch.Common;
IMPORT TextSearch.Inverted.Layouts;
Document := Layouts.Document;
RawPosting := Layouts.RawPosting;
Types := Common.Types;
Constants := Common.Constants;

EXPORT DATASET(RawPosting) ParsedText(DATASET(Document) docsInput) := FUNCTION
  // Tokenize content
  Common.Pattern_Definitions()
  PATTERN TagEndSeq     := U'/>' OR U'>';
  PATTERN Equals        := OPT(Spaces) U'=' OPT(Spaces);
  PATTERN StartNameChar	:= Letter OR Colon OR Underscore;
  PATTERN NameChar			:= StartNameChar OR Hyphen OR Period OR Digit OR MidDot;
  PATTERN XMLName				:= StartNameChar NameChar*;
  PATTERN EndElement    := U'</' OPT(Spaces) XMLName OPT(Spaces) U'>';
  PATTERN AnyNoAposStr  := AnyNoApos+;
  PATTERN AposValueWrap := '\'' OPT(AnyNoAposStr) '\'';
  PATTERN AnyNoQuoteStr := AnyNoQuote+;
  PATTERN QuotValueWrap := '"' OPT(AnyNoQuoteStr) '"';
  PATTERN ValueExpr     := Equals (AposValueWrap OR QuotValueWrap);
  PATTERN EmptyAttribute:= Spaces  XMLName NOT BEFORE ValueExpr;
  PATTERN ValueAttribute:= Spaces  XMLName ValueExpr;
  PATTERN AttrListItem  := EmptyAttribute OR ValueAttribute;
  PATTERN AttributeList := REPEAT(AttrListItem) OPT(Spaces) TagEndSeq;
  PATTERN AttributeExpr := AttrListItem BEFORE AttributeList;
  PATTERN XMLComment    := U'<!--' (AnyNoHyphen OR (U'-' AnyNoHyphen))* U'-->';
  PATTERN VersionInfo   := U'version' OPT(Spaces) ValueExpr;
  PATTERN EncodingInfo  := U'encoding' OPT(Spaces) ValueExpr;
  PATTERN SDDecl        := U'standalone' OPT(Spaces) ValueExpr;
  PATTERN XMLDecl       := U'<?xml' Spaces VersionInfo
                           OPT(Spaces EncodingInfo) OPT(Spaces EncodingInfo)
                           OPT(Spaces SDDecl) OPT(Spaces) U'?>';
  PATTERN ContainerEnd  := REPEAT(AttrListItem) OPT(Spaces) U'>';
  PATTERN EmptyEnd      := REPEAT(AttrListItem) OPT(Spaces) U'/>';
  PATTERN XMLElement    := U'<' XMLName BEFORE ContainerEnd;
  PATTERN XMLEmpty      := U'<' XMLName BEFORE EmptyEnd;

  RULE myRule           := XMLDecl OR XMLComment OR XMLElement OR XMLEmpty OR
													 AttributeExpr OR EndElement OR TagEndSeq OR
                           WordAlphaNum OR WhiteSpace OR PoundCode OR WordNoLetters OR 
													 WordAllLower OR WordAllUpper OR WordTitleCase OR
													 WordMixedCase OR  SymbolChar OR Noise OR AnyChar OR AnyPair OR WordAlphaNum2;

  RawPosting parseString(Document doc) := TRANSFORM
    SELF.id        := doc.id;;
    SELF.kwp       := 0;
    SELF.start     := MATCHPOSITION(MyRule);
    SELF.stop      := MATCHPOSITION(MyRule) + MATCHLENGTH(MyRule) - 1;
    SELF.depth     := 0;
    SELF.pathString:= U'';
		
    SELF.len       := MATCHLENGTH(MyRule);
    SELF.lenText   := MAP(
        MATCHED(WhiteSpace)                      => MATCHLENGTH(MyRule),
        MATCHED(SymbolChar)                      => MATCHLENGTH(MyRule),
        MATCHED(Noise)                           => MATCHLENGTH(MyRule),
        MATCHED(WordAlphaNum)                    => MATCHLENGTH(MyRule),
        MATCHED(AnyChar)                         => MATCHLENGTH(MyRule),
        MATCHED(AnyPair)                         => MATCHLENGTH(MyRule),
        0);
    SELF.keywords  := MAP(
        MATCHED(SymbolChar)                      => 1,
        MATCHED(WordAlphaNum)                    => 1,
        MATCHED(AnyChar)                         => 1,
        MATCHED(AnyPair)                         => 1,
        0);
    SELF.typTerm   := MAP(
        MATCHED(WhiteSpace)                      => Types.TermType.WhiteSpace,
        MATCHED(SymbolChar)                      => Types.TermType.SymbolChar,
        MATCHED(Noise)                           => Types.TermType.NoiseChar,
        MATCHED(WordAlphaNum2)                    => Types.TermType.TextStr,
        MATCHED(AnyChar)                         => Types.TermType.SymbolChar,
        MATCHED(AnyPair)                         => Types.TermType.SymbolChar,
        MATCHED(XMLDecl)                         => Types.TermType.Tag,
        MATCHED(XMLComment)                      => Types.TermType.Tag,
        MATCHED(XMLElement)                      => Types.TermType.Tag,
        MATCHED(XMLEmpty)                        => Types.TermType.Tag,
        MATCHED(AttributeExpr)                   => Types.TermType.Tag,
        MATCHED(EndElement)                      => Types.TermType.Tag,
        MATCHED(TagEndSeq)                       => Types.TermType.Tag,
        MATCHED(PoundCode)                       => Types.TermType.TextStr,
        Types.TermType.Unknown);
		//It is PCData if the stack depth is greater than 1 and the parentOrd is > 2
    SELF.typData   := MAP(
        MATCHED(WhiteSpace)                      => Types.DataType.RawData,
        MATCHED(SymbolChar)                      => Types.DataType.RawData,
        MATCHED(Noise)                           => Types.DataType.RawData,
        MATCHED(WordAlphaNum)                    => Types.DataType.RawData,
        MATCHED(AnyChar)                         => Types.DataType.RawData,
        MATCHED(AnyPair)                         => Types.DataType.RawData,
        MATCHED(XMLDecl)                         => Types.DataType.XMLDecl,
        MATCHED(XMLComment)                      => Types.DataType.XMLComment,
        MATCHED(XMLElement)                      => Types.DataType.Element,
        MATCHED(XMLEmpty)                        => Types.DataType.Element,
        MATCHED(AttributeExpr/EmptyAttribute)    => Types.DataType.Attribute,
        MATCHED(AttributeExpr/ValueAttribute)    => Types.DataType.Attribute,
        MATCHED(EndElement)                      => Types.DataType.EndElement,
        MATCHED(TagEndSeq)                       => Types.DataType.TagEndSeq,
        MATCHED(PoundCode)                       => Types.DataType.RawData,
        Types.DataType.Unknown);
    SELF.tagValue  := MAP(
        NOT MATCHED(AttributeExpr)              => U'',
        MATCHED(QuotValueWrap)                  => MATCHUNICODE(AnyNoQuoteStr),
        MATCHED(AposValueWrap)                  => MATCHUNICODE(AnyNoAposStr),
        U'');
    SELF.tagName   := MAP(
        MATCHED(EmptyAttribute/XMLName)         => MATCHUNICODE(XMLName),
        MATCHED(ValueAttribute/XMLName)         => MATCHUNICODE(XMLName),
        MATCHED(XMLElement)                     => MATCHUNICODE(XMLName),
        MATCHED(XMLEmpty)                       => MATCHUNICODE(XMLName),
        MATCHED(EndElement)                     => MATCHUNICODE(XMLName),
        U'');
    SELF.preorder  := 0;
    SELF.parentOrd := 0;
    SELF.parentName:= U'';
		Self.lp := MAP(
			MATCHED(WordAlphaNum/WordAllUpper) => Types.LetterPattern.UpperCase,
			MATCHED(WordAlphaNum/WordAllLower) => Types.LetterPattern.LowerCase,
			MATCHED(WordTitleCase) => Types.LetterPattern.TitleCase,
			MATCHED(WordMixedCase) => Types.LetterPattern.MixedCase,
			Types.LetterPattern.NoLetters);
    SELF.term      := MATCHUNICODE(MyRule);
  END;
  p0 := PARSE(docsInput, content, myRule, parseString(LEFT), MAX, MANY, NOT MATCHED);
	//p1 returns and shows the errors, which makes the runtime slow, so it is commented out for now.
  //p1 := ASSERT(p0, typTerm<>Types.TermType.Unknown, Constants.OtherCharsInText_Msg);
	//RETURN p1(typTerm <> Types.TermType.WhiteSpace);
  RETURN p0(typTerm <> Types.TermType.WhiteSpace);
END;