

(* Wolfram Language Raw Program *)

BeginPackage["Tma2tex`"];

(* ---- written by Jack Heseltine, July 2023
	Updates August 2023: Recursion Rules
	
	Purpose: This program recurses over the Theorema notebook structure to produce a LaTeX representation. The patterns
		are specified in Part 1 of the program and this is where the program would typically be extended in the future.
		The result is inserted into the appropriate LaTeX template (Part 2, Filehandling): the main function intended 
		for use by the client is at the end of the program, Part 3.
		
	Usage: call one of the variants of the main function, see
		a) convertToLatexDoc[notebookPath_], where notebookPath specifies the Mathematica/Wolfram Lang. notebook to be converted, 
				the output is a TeX file at the level of notebookPath.
			Dependencies: There has to be a LaTeX template in a reachable directory corresponding to the module variable resourceDir.
		b) convertToLatexAndPDFDocs[notebookPath_]: same as above, but also produces a PDF file at the level of the TeX.
			Dependencies: Template as above, but also requires a working TeX distribution installed on your system.
		c) convertToLatexFromString[nbContentString_, resourceDir_Optional]: experimental, intended be called from the Cloud, 
			simply transofrming Wolfram Language String Input to TeX Output (returned directly, not via file). 
			Also uses a template, the resource for which can be passed as the second argument.
	 ---- *)

(* -- Part 0, Global Variables as per Theorema Specification -- *)

Tma2tex`$resDir::usage="Points to ..."

Tma2tex`$resDir = "C:\\Users\\jackh\\git\\repository\\tma2tex\\res"

convertToLatexDoc::usage="convertToLatexDoc[notebookPath] transforms a given WL notebook (by file path) to TeX output, creating a new TeX file from a specified resource template."
convertToLatexAndPDFDocs::usage="convertToLatexAndPDFDocs[notebookPath] transforms a given WL notebook (by file path) to PDF file as final output, with TeX file as intermediary step, from a specified resource template."
convertToLatexFromString::usage="convertToLatexFromString[nbContentString_, resourceDir_Optional]: Tma2tex`$resDir] is experimental and intended be called from the Cloud, simply transofrming Wolfram Language String Input to TeX Output (returned directly, not via file). Also uses a template, the resource for which can be passed as the second argument."

Begin["`Private`"]

(* -- Part 1, Recursive Pattern Matching: parseNotebookContent[] -- *)

(* -- Part 1.0 -- In-Flow Expressions: these are processed one after the other *)

(* -- Part 1.0.0 -- Structural Expressions: \light{}-TeX Command available in Frontend, to demarcate structural text output from content *)

(*parseNotebookContent[Notebook[l_List, ___]] := "NB reached " <> parseNotebookContent /@ l*) (* goes to parseNotebookContent[c_Cell], see Map *)
parseNotebookContent[Notebook[l_List, ___]] := "\\light{NB reached} " <> parseNotebookContent[l] (* goes to parseNotebookContent[l_List] *)


parseNotebookContent[c_Cell] := "\\light{Cell reached} "

parseNotebookContent[l_List] := "\\light{List reached1} "
parseNotebookContent[l_List] /; MemberQ[l, _Cell] := StringJoin["\\light{List reached2} ", ToString /@ parseNotebookContent /@ l] 


parseNotebookContent[Cell[CellGroupData[l_List, ___], ___]] := "\\light{CellGroupData reached} " <> parseNotebookContent[l]


(* -- Part 1.0.1 -- Text Expressions *)

parseNotebookContent[Cell[text_String, "Text", ___]] := "\\begingroup \\section*{} " <> text <> "\\endgroup \n\n"

parseNotebookContent[Cell[text_String, "Section", ___]] := "\\section{" <> text <> "}\n\n"


(* -- Part 1.0.2 -- Math Expressions (Non-Theorema-specific) *)

(* -- Part 1.0.2.0 -- Boxes *)

parseNotebookContent[Cell[BoxData[FormBox[content_, TraditionalForm]], "DisplayFormula", ___]] := 
    StringJoin["\\begin{center}", parseNotebookContent[content], "\\end{center}\n"]

parseNotebookContent[RowBox[list_List]] := 
    StringJoin[parseNotebookContent /@ list]

parseNotebookContent[UnderscriptBox[base_, script_]] := 
    StringJoin["\\underset{", parseNotebookContent[script], "}{", parseNotebookContent[base], "}"]

parseNotebookContent[UnderscriptBox["\[ForAll]", var_]] := 
    StringJoin["\\forall ", parseNotebookContent[var], ", "]

    
(* -- Part 1.0.2.1 -- Symbols (complete list needed? First Order Logic?) *)

parseNotebookContent[RowBox[{left_, "\[And]", right_}]] := 
    StringJoin[parseNotebookContent[left], " \\land ", parseNotebookContent[right]]

parseNotebookContent[RowBox[{left_, "\[Or]", right_}]] := 
    StringJoin[parseNotebookContent[left], " \\lor ", parseNotebookContent[right]]

parseNotebookContent[RowBox[{left_, "\[DoubleLeftRightArrow]", right_}]] := 
    StringJoin[parseNotebookContent[left], " \\Leftrightarrow ", parseNotebookContent[right]]

parseNotebookContent[RowBox[{left_, "\[Implies]", right_}]] := 
    StringJoin[parseNotebookContent[left], " \\Rightarrow ", parseNotebookContent[right]]
    

(* -- Part 1.0.2.1 -- Brackets: this rule might be contentious *)

parseNotebookContent[RowBox[{func_, "[", arg_, "]"}]] := 
    StringJoin[parseNotebookContent[func], "(", parseNotebookContent[arg], ")"]
    
    
(* -- Part 1.1 -- Theorema-Language-specific Expressions *)



(* -- Part 1.2 -- Out-of-Flow Expressions: Reap and Sow mechanism to process in a different order than the expressions are encountered in *)

parseNotebookContent[Cell[t_String, "Title", ___]] := (Sow[t, "title"]; Sow["", "author"]; Sow["", "date"];) (* author and date currently not included in sample doc *)



(* -- Part 1.3 -- Key for Testing? -- Unclaimed Expressions *)

parseNotebookContent[other_] := ToString[other] (* handle other patterns, like individual elements within a Cell's content *)




(* -- Part 2, Filehandling -- *)

writeToLatexDoc[latexPath_, nbContent_] := 
 Module[{strm }, strm = OpenWrite[latexPath];
  WriteString[strm, parseNotebookContent[nbContent]]; 
  Close[strm]] (* stream handling, call to pattern Matching part *)
  
getLatexPath[notebookPath_String] := 
 Module[{directory, baseName, latexExtension = ".tex"}, 
  directory = DirectoryName[notebookPath];
  baseName = FileBaseName[notebookPath];
  FileNameJoin[{directory, 
    baseName <> 
     latexExtension}]] (* get the latex file name (the new .tex file \
that is being filled with the nb-content) with full path from a given \
notebook path*)

getLatexTemplatePath[notebookPath_String] := 
 Module[{directory, baseName, latexExtension = ".tex"}, 
  directory = DirectoryName[notebookPath];
  baseName = FileBaseName[notebookPath] <> "TheoremaTemplate";
  FileNameJoin[{directory, 
    baseName <> 
     latexExtension}]] (* get the latex file name (the .tex-template \
which includes the main nb-content-.tex-file correctly) with full \
path from a given notebook path*)

fillLatexTemplate[resDir_String, data_Association] := 
 Module[{texContent, template, 
   filledContent},(*Import the LaTeX template*)
  texContent = 
   Import[FileNameJoin[{resDir, "tmaTemplate.tex"}], "Text"];
  (*no template object needed here*)template = texContent;
  (*Apply the data to the template*)
  filledContent = TemplateApply[template, data];
  (*Return the filled content*)filledContent]
  
  
  
(* -- Part 3, Main Functions for Client -- *)
  
convertToLatexDoc[notebookPath_] :=  Module[{nb, content, latexPath, latexTemplatePath, 
   resourceDir = $resDir, texResult, sownData, filledContent},
  nb = NotebookOpen[notebookPath, Visible->False];
  content = NotebookGet[nb];
  NotebookEvaluate[content]; (* on content: important, 
    so that Tma env. variables are available in any case *)
  latexPath = getLatexPath[notebookPath];
  latexTemplatePath = getLatexTemplatePath[notebookPath]; 
  (*filledContent = 
   fillLatexTemplate[
    resourceDir, <|"nbName" -> FileBaseName[notebookPath]|>];*)
  {texResult, sownData} = Reap[parseNotebookContent[content], {"title", "author", "date"}];
  filledContent = fillLatexTemplate[resourceDir,
  <|
    "nbContent" -> texResult,
    "nbTitle" -> First[sownData[[1, 1]]],
    "nbAuthor" -> First[sownData[[2, 1]]],
    "nbDate" -> First[sownData[[3, 1]]]
  |>];
  Export[latexPath, filledContent, "Text"];
]

convertToLatexAndPDFDocs[notebookPath_] :=  Module[{latexPath, pdfPath, compileCmd},
  convertToLatexDoc[notebookPath];
  (* Compile LaTeX to PDF using pdflatex *)
  latexPath = getLatexPath[notebookPath];
  pdfPath = StringReplace[latexPath, ".tex" -> ".pdf"];
  compileCmd = 
   "pdflatex -interaction=nonstopmode -output-directory=" <> 
    DirectoryName[latexPath] <> " " <> latexPath;
  RunProcess[{"cmd", "/c", compileCmd}];
]

convertToLatexFromString[nbContentString_, resourceDir_Optional: Tma2tex`$resDir] := Module[
    {nbContent, texResult, sownData, filledContent},
    
    (* Convert the string representation to a Wolfram Language expression *)
    nbContent = ToExpression[nbContentString, InputForm];

    (* Process the notebook content *)
    {texResult, sownData} = Reap[parseNotebookContent[nbContent], {"title", "author", "date"}];

    (* Fill in the LaTeX template with parsed content *)
    filledContent = fillLatexTemplate[resourceDir,
        <|
            "nbContent" -> texResult,
            "nbTitle" -> First[sownData[[1, 1]]],
            "nbAuthor" -> First[sownData[[2, 1]]],
            "nbDate" -> First[sownData[[3, 1]]]
        |>
    ];

    (* Return the filled LaTeX content as a string *)
    filledContent
]

End[]

EndPackage[];
  