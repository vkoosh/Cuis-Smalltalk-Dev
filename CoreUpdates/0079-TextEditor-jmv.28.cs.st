'From Squeak3.7 of ''4 September 2004'' [latest update: #5989] on 5 November 2008 at 10:19:34 pm'!
		stop: contents size
		internalSpaces: 0
		paddingWidth: 0.
		rectangle: bounds;
		lineHeight: f height baseline: f ascent.
	"Perform the changes in interactionBlock, noting any change in selection
	and possibly a change in the size of the paragraph (ar 9/22/2001 - added for TextPrintIts)"

	"Also couple the editor to Morphic keyboard events"

	| oldEditor oldContents |
	self editor sensor: (OldKeyboardBuffer new startingEvent: evt).
	oldEditor := editor.
	oldContents := contents.
	interactionBlock value.
	oldContents == contents 
		ifTrue: 
			["this will not work if the paragraph changed"

			editor := oldEditor	"since it may have been changed while in block"].
	"Install an editor for my contents.  This constitutes 'hasFocus'.
	If priorEditor is not nil, then initialize the new editor from its state.
	We may want to rework this so it actually uses the prior editor."

	| stateArray |
	priorEditor ifNotNil: [stateArray := priorEditor stateArray].
	editor := SimpleEditor new morph: self.
	editor changeString: contents.
	priorEditor ifNotNil: [editor stateArrayPut: stateArray].
	self changed.
	^editor! !

	"Private - Move cursor end of current line."
	self closeTypeIn: characterStream.
	self
		moveCursor:
			[:position | 
		forward: true
		specialBlock:[:dummy | string size + 1].
	^true! !
	"Set the FindText and ChangeText to seek aString; except if already seeking aString, leave ChangeText alone so again will repeat last replacement."

	FindText string = aString
		ifFalse: [FindText _ ChangeText _ aString asText]! !
	"Change the emphasis of the current selection or prepare to accept characters with the change in emphasis. Emphasis change amounts to a font change.  Keeps typeahead."

	"control 0..9 -> 0..9"

	| keyCode attribute oldAttributes index thisSel colors extras |
	keyCode := ('0123456789-=' indexOf: sensor keyboard ifAbsent: [1]) - 1.
	oldAttributes := paragraph text attributesAt: self pointIndex
				forStyle: paragraph textStyle.
	thisSel := self selection.

	"Decipher keyCodes for Command 0-9..."
	(keyCode between: 1 and: 5) 
		ifTrue: [attribute := TextFontChange fontNumber: keyCode].
	keyCode = 6 
		ifTrue: 
			[colors := #(#black #magenta #red #yellow #green #blue #cyan #white).
			extras := (self morph isKindOf: OldTextMorphForEditView)
							ifFalse: 
								["not a system window"

								#()]
							ifTrue: 
								[#('Link to comment of class' 'Link to definition of class' 'Link to hierarchy of class' 'Link to method')].
			index := (PopUpMenu 
						labelArray: colors , #('choose color...' 'Do it' 'Print it') , extras 
								, #('be a web URL link' 'Edit hidden info' 'Copy hidden info')
						lines: (Array with: colors size + 1)) startUp.
			index = 0 ifTrue: [^true].
			index <= colors size 
				ifTrue: [attribute := TextColor color: (Color perform: (colors at: index))]
				ifFalse: 
					[index := index - colors size - 1.	"Re-number!!!!!!"
					index = 0 ifTrue: [attribute := self chooseColor].
					index = 1 
						ifTrue: 
							[attribute := TextDoIt new.
							thisSel := attribute analyze: self selection asString].
					index = 2 
						ifTrue: 
							[attribute := TextPrintIt new.
							thisSel := attribute analyze: self selection asString].
					extras size = 0 & (index > 2) ifTrue: [index := index + 5].	"skip those"
					index = 3 
						ifTrue: 
							[attribute := TextLink new.
							thisSel := attribute analyze: self selection asString with: 'Comment'].
					index = 4 
						ifTrue: 
							[attribute := TextLink new.
							thisSel := attribute analyze: self selection asString with: 'Definition'].
					index = 5 
						ifTrue: 
							[attribute := TextLink new.
							thisSel := attribute analyze: self selection asString with: 'Hierarchy'].
					index = 6 
						ifTrue: 
							[attribute := TextLink new.
							thisSel := attribute analyze: self selection asString].
					index = 7 
						ifTrue: 
							[attribute := TextURL new.
							thisSel := attribute analyze: self selection asString].
					index = 8 
						ifTrue: 
							["Edit hidden info"

							thisSel := self hiddenInfo.	"includes selection"
							attribute := TextEmphasis normal].
					index = 9 
						ifTrue: 
							["Copy hidden info"

							self copyHiddenInfo.
							^true].	"no other action"
					thisSel ifNil: [^true]	"Could not figure out what to link to"]].
	(keyCode between: 7 and: 11) 
		ifTrue: 
			[sensor leftShiftDown 
				ifTrue: 
					[keyCode = 10 ifTrue: [attribute := TextKern kern: -1].
					keyCode = 11 ifTrue: [attribute := TextKern kern: 1]]
				ifFalse: 
					[attribute := TextEmphasis 
								perform: (#(#bold #italic #narrow #underlined #struckOut) at: keyCode - 6).
					oldAttributes 
						do: [:att | (att dominates: attribute) ifTrue: [attribute turnOff]]]].
	keyCode = 0 ifTrue: [attribute := TextEmphasis normal].
	beginTypeInBlock ~~ nil 
		ifTrue: 
			["only change emphasisHere while typing"

			self insertTypeAhead: characterStream.
			emphasisHere := Text addAttribute: attribute toArray: oldAttributes.
			^true].
	self replaceSelectionWith: (thisSel asText addAttribute: attribute).
	^true! !
	"Make a new Text Color Attribute, let the user pick a color, and return the attribute"

	| attribute |
	(OldColorPickerMorph new)
		choseModalityFromPreference;
		sourceHand: morph activeHand;
		target: (attribute := TextColor color: Color black);
		selector: #color:;
		originalColor: Color black;
		putUpFor: morph near: morph fullBoundsInWorld.	"default"
	^attribute! !
	"Save the receiver's contents string to a file, prompting the user for a file-name.  Suggest a reasonable file-name."

	| fileName stringToSave parentWindow labelToUse suggestedName lastIndex |
	stringToSave := paragraph text string.
	stringToSave size == 0 ifTrue: [^self inform: 'nothing to save.'].
	parentWindow := self model dependents 
				detect: [:dep | dep isKindOf: OldSystemWindow]
				ifNone: [nil].
	labelToUse := parentWindow ifNil: ['Untitled']
				ifNotNil: [parentWindow label].
	suggestedName := nil.
	#(#('Decompressed contents of: ' '.gz')) do: 
			[:leaderTrailer | 
			"can add more here..."

			(labelToUse beginsWith: leaderTrailer first) 
				ifTrue: 
					[suggestedName := labelToUse copyFrom: leaderTrailer first size + 1
								to: labelToUse size.
					(labelToUse endsWith: leaderTrailer last) 
						ifTrue: 
							[suggestedName := suggestedName copyFrom: 1
										to: suggestedName size - leaderTrailer last size]
						ifFalse: 
							[lastIndex := suggestedName lastIndexOf: $. ifAbsent: [0].
							(lastIndex = 0 or: [lastIndex = 1]) 
								ifFalse: [suggestedName := suggestedName copyFrom: 1 to: lastIndex - 1]]]].
	suggestedName ifNil: [suggestedName := labelToUse , '.text'].
	fileName := FillInTheBlank request: 'File name?'
				initialAnswer: suggestedName.
	fileName isEmptyOrNil 
		ifFalse: 
			[(FileStream newFileNamed: fileName)
				nextPutAll: stringToSave;
				close]! !

	"Private - Move cursor end of current line."
	| string |
	self closeTypeIn: characterStream.
	string _ paragraph text string.
	self
		moveCursor:
			[:position | Preferences wordStyleCursorMovement
				ifTrue:[| targetLine |
					targetLine _ paragraph lines at:(paragraph lineIndexOfCharacterIndex: position).
					targetLine = paragraph lastLine
						ifTrue:[targetLine last + 1]
						ifFalse:[targetLine last]]
				ifFalse:[
					string
						indexOf: Character cr
						startingAt: position
						ifAbsent:[string size + 1]]]
		forward: true
		specialBlock:[:dummy | string size + 1].
	^true! !
	(morph respondsTo: #editView) 
		ifTrue: [morph editView selectionInterval: self selectionInterval]! !
	"Answer the menu to be presented when the yellow button is pressed while the shift key is down"

	^ SelectionMenu fromArray: {
		{'set font... (k)' translated.					#offerFontMenu}.
		{'set style... (K)' translated.					#changeStyle}.
		{'set alignment...' translated.				#chooseAlignment}.
		#-.
		{'explain' translated.						#explain}.
		{'pretty print' translated.					#prettyPrint}.
		{'pretty print with color' translated.			#prettyPrintWithColor}.
		{'file it in (G)' translated.					#fileItIn}.
		{'spawn (o)' translated.						#spawn}.
		#-.
		{'browse it (b)' translated.					#browseIt}.
		{'senders of it (n)' translated.				#sendersOfIt}.
		{'implementors of it (m)' translated.		#implementorsOfIt}.
		{'references to it (N)' translated.			#referencesToIt}.
		#-.
		{'selectors containing it (W)' translated.	#methodNamesContainingIt}.
		{'method strings with it (E)' translated.	#methodStringsContainingit}.
		{'method source with it' translated.		#methodSourceContainingIt}.
		{'class names containing it' translated.	#classNamesContainingIt}.
		{'class comments with it' translated.		#classCommentsContainingIt}.
		{'change sets with it' translated.			#browseChangeSetsWithSelector}.
		#-.
		{'save contents to file...' translated.		#saveContentsInFile}.
		{'send contents to printer' translated.		#sendContentsToPrinter}.
		{'printer setup' translated.					#printerSetup}.
		#-.
		{'special menu...' translated.				#presentSpecialMenu}.
		{'more...' translated.							#yellowButtonActivity}.
	}! !