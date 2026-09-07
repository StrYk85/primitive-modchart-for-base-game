// package vmodchart;

// import funkin.modding.module.Module;

// import funkin.play.PlayState;
// import funkin.play.notes.Strumline;
// import funkin.play.notes.notestyle.NoteStyle;
// import funkin.util.GRhythmUtil;

// import flixel.group.FlxSpriteGroup;
// import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
// import flixel.math.FlxAngle;

// class ModchartSetupModule extends Module {
//     // TODO: Maybe do this implementation via the ScriptedStrumline class

//     // idk......................
//     public function new() {
//         super('ModchartSetupModule', 100, {state:PlayState});
//     }

//     private var game(get, never):PlayState;
//     function get_game():PlayState {
//         return PlayState.instance;
//     }

//     public var strumlineGroup:Array<Strumline> = [];
//     public var bakedAngles:Array<Array<Float>> = [];
//     public var holdGroups:Array<FlxTypedSpriteGroup> = [];
//     public var coverGroups:Array<FlxTypedSpriteGroup> = [];

//     public function addStrumlineToGroup(strumline:Strumline) {
//         var neoHolds:FlxTypedSpriteGroup = new FlxTypedSpriteGroup();
//         neoHolds.zIndex = 15;
//         strumline.add(neoHolds);
//         holdGroups.push(neoHolds);

//         var neoCovers:FlxTypedSpriteGroup = new FlxTypedSpriteGroup();
//         neoCovers.zIndex = 35;
//         strumline.add(neoCovers);
//         coverGroups.push(neoCovers);
        
//         strumline.customPositionData = true;
//         strumline.refresh();

//         strumlineGroup.push(strumline);
//         bakedAngles.push([for (direction in Strumline.DIRECTIONS) 0.0]);
//     }

//     public function setBakedAngle(strumlineID, strumID, value) {
//         if (bakedAngles[strumlineID] != null && bakedAngles[strumlineID][strumID] != null)
//             bakedAngles[strumlineID][strumID] = value;
//     }

//     public function getStrumline(strumlineID) {
//         return strumlineGroup[strumlineID];
//     }

//     public function getStrumNote(strumlineID, strumID) {
//         return strumlineGroup[strumlineID].strumlineNotes.members[strumID];
//     }

//     function onStateChangeEnd(e) {
//         super.onStateChangeEnd(e);
//         strumlineGroup = [];
//         holdGroups = [];
//         coverGroups = [];
//         bakedAngles = [];
//         for (strumline in [game.playerStrumline, game.opponentStrumline]) addStrumlineToGroup(strumline);
//     }

//     function onUpdate(e) {
//         super.onUpdate(e);
//         if (game.isGamePaused) return;

//         for (strumline in strumlineGroup) {
//             if (strumline == null) continue;
//             var strumlineID = strumlineGroup.indexOf(strumline);

//             for (note in strumline.notes.members) {
//                 if (note == null || !note.alive) continue;
//                 final direction:Int = note.noteData.getDirection();
//                 final strumNote:StrumlineNote = strumline.strumlineNotes.members[direction];

//                 final notePos:Float = getNoteY(note.strumTime, strumline);
//                 final daAngle = bakedAngles[strumlineID][direction];
//                 final xPos:Float = notePos * -Math.sin(daAngle * FlxAngle.TO_RAD);
//                 final yPos:Float = notePos * Math.cos(daAngle * FlxAngle.TO_RAD);
                
//                 final strumX:Float = strumNote.x + (strumNote.width - note.width) / 2;
//                 final strumY:Float = strumNote.y + (strumNote.height - note.height) / 2;

//                 note.x = strumX + xPos;
//                 note.y = strumY + yPos;
//             }

//             var holdGroup = holdGroups[strumlineID];
//             if (holdGroup != null) {
//                 for (holdNote in holdGroup.members) {
//                     if (holdNote == null || !holdNote.alive) continue;
//                     final direction:Int = holdNote.noteDirection;
//                     final strumline:Strumline = holdNote.parentStrumline;
//                     final strumNote:StrumlineNote = strumline.strumlineNotes.members[direction];

//                     final isPlayer:Bool = strumline.isPlayer;
//                     final conductor:Conductor = strumline.conductorInUse;

//                     final renderWindowEnd:Float = holdNote.strumTime + holdNote.fullSustainLength + Constants.HIT_WINDOW_MS + (strumline.renderDistanceMs / 8);

//                     final notePos:Float = getNoteY(holdNote.strumTime, strumline);
//                     final daAngle = bakedAngles[strumlineID][direction];
//                     final xPos:Float = notePos * -Math.sin(daAngle * FlxAngle.TO_RAD);
//                     final yPos:Float = notePos * Math.cos(daAngle * FlxAngle.TO_RAD);

//                     holdNote.angle = daAngle;
                
//                     final strumX:Float = strumNote.x + (strumNote.width - holdNote.width) / 2;
//                     final strumY:Float = strumNote.y + strumNote.height / 2;

//                     var cover:CoverSprite = null;
//                     final coverGroup = coverGroups[strumlineID];
//                     if (coverGroup != null) {
//                         for (coverSprite in coverGroup.members) {
//                             if (coverSprite == null || !coverSprite.alive) continue;
//                             if (coverSprite.noteDirection == holdNote.noteDirection && coverSprite.isPlayer == isPlayer) {
//                                 cover = coverSprite;
//                                 cover.angle = holdNote.angle;
//                                 break;
//                             }
//                         }
//                     }

//                     if (conductor.songPosition > holdNote.strumTime && holdNote.hitNote && !holdNote.missedNote) {
//                         if (isPlayer && !strumline.isKeyHeld(direction)) {
//                             strumline.playStatic(direction);
//                             holdNote.missedNote = true;
//                             holdNote.visible = true;
//                             holdNote.alpha = 0;
//                         }
//                     }

//                     if (holdNote.missedNote && conductor.songPosition >= renderWindowEnd) {
//                         holdNote.kill();
//                     }
//                     else if (holdNote.hitNote && holdNote.sustainLength <= 0) {
//                         if (strumline.isKeyHeld(direction)) strumline.playPress(direction);
//                         else strumline.playStatic(direction);

//                         if (cover != null) cover.playEnd();
//                         holdNote.kill();
//                     }
//                     else if (holdNote.missedNote && (holdNote.fullSustainLength > holdNote.sustainLength)) {
//                         holdNote.visible = true;

//                         holdNote.y = strumY + yPos + ((holdNote.fullSustainLength - holdNote.sustainLength) * Constants.PIXELS_PER_MS);
//                         holdNote.x = strumX + xPos;
//                         if (cover != null) cover.kill();
//                     }
//                     else if (conductor.songPosition > holdNote.strumTime && holdNote.hitNote) {
//                         holdNote.visible = true;

//                         strumline.holdConfirm(direction);
//                         holdNote.sustainLength = (holdNote.strumTime + holdNote.fullSustainLength) - conductor.songPosition;
//                         holdNote.y = strumY;
//                         holdNote.x = strumX;
//                     }
//                     else {
//                         holdNote.visible = true;
//                         holdNote.y = strumY + yPos;
//                         holdNote.x = strumX + xPos;
//                     }

//                     if (cover != null) {
//                         cover.positionToStrumline(strumline);
//                         cover.visible = true;
//                     }

//                     if (holdNote.hitNote && !holdNote.missedNote && holdNote.sustainLength > 0) {
//                         if (isPlayer) {
//                             if (!game.isBotPlayMode && holdNote.scoreable) {
//                                 game.health += Constants.HEALTH_HOLD_BONUS_PER_SECOND * e.elapsed;
//                                 game.songScore += Constants.SCORE_HOLD_BONUS_PER_SECOND * e.elapsed;
//                             }

//                             // im not bothered to copy the other stuff at the moment
//                         }

//                         var char = isPlayer? game.currentStage?.getBoyfriend() : game.currentStage?.getDad();
//                         if (game.currentStage != null && char != null && char.isSinging()) {
//                             if ((isPlayer && game.isBotPlayMode) || !isPlayer)
//                                 char.holdTimer = 0;
//                         }
//                     }
//                 }
//             }
//         }
//     }

//     function onNoteIncoming(e) {
//         super.onNoteIncoming(e);
//         var oldSustain = e.note.holdNoteSprite;
//         if (e.note.length > 0 && oldSustain != null) {
//             final strumline = oldSustain.parentStrumline;
//             final strumIndex = e.note.noteData.getStrumlineIndex();

//             var newSustain = constructSustainSprite(strumIndex);
//             newSustain.copySustain(oldSustain);
//             newSustain.missedNote = newSustain.hitNote = false;
//             newSustain.visible = true;
//             newSustain.alpha = 1.0;

//             oldSustain.kill();
//             e.note.holdNoteSprite = null;

//             newSustain.y = -9999;
//             newSustain.x = -9999;
//             newSustain.alive = newSustain.active = true;
//             newSustain.angle = bakedAngles[strumIndex][oldSustain.noteDirection];
//         }
//     }

//     function onNoteHit(e) {
//         super.onNoteHit(e);
//         final holdNote = getHoldNote(e.note);
//         if (holdNote != null) {
//             holdNote.hitNote = true;
//             holdNote.missedNote = false;

//             final strumline = holdNote.parentStrumline;
//             final strumIndex = e.note.noteData.getStrumlineIndex();
//             final songPos = strumline.conductorInUse.songPosition;
//             holdNote.sustainLength = Math.min(holdNote.fullSustainLength, (holdNote.strumTime + holdNote.fullSustainLength) - songPos);

//             var cover = constructCoverSprite(strumIndex);
//             cover.noteDirection = holdNote.noteDirection;
//             cover.isPlayer = strumline.isPlayer;
//             cover.playStart();
//             cover.positionToStrumline(strumline);
//         }
//     }

//     function onSongRetry(e) {
//         super.onSongRetry(e);
//         for (holdGroup in holdGroups) {
//             if (holdGroup == null) continue;
//             for (hold in holdGroup.members) {
//                 if (hold == null) continue;
//                 hold.kill();
//             }
//         }

//         for (coverGroup in coverGroups) {
//             if (coverGroup == null) continue;
//             for (cover in coverGroup.members) {
//                 if (cover == null) continue;
//                 cover.kill();
//             }
//         }
//     }

//     function constructSustainSprite(strumID:Int):SustainSprite {
//         var dummy = null;
//         var strumline = strumlineGroup[strumID];
//         var holdGroup = holdGroups[strumID];

//         dummy = holdGroup.getFirstAvailable();

//         if (dummy == null) {
//             dummy = new SustainSprite(0, 0, strumline.noteStyle);
//             holdGroup.add(dummy);
//         }
//         else 
//             dummy.revive();

//         return dummy;
//     }

//     function constructCoverSprite(strumID:Int):CoverSprite {
//         var dummy = null;
//         var strumline = strumlineGroup[strumID];
//         var coverGroup = coverGroups[strumID];

//         dummy = coverGroup.getFirstAvailable();

//         if (dummy == null) {
//             dummy = new CoverSprite(strumline.noteStyle);
//             coverGroup.add(dummy);
//         }
//         else 
//             dummy.revive();

//         return dummy;
//     }

//     function getHoldNote(note:NoteSprite):SustainSprite {
//         if (note.noteData.length > 0) {
//             var holdGroup = holdGroups[note.noteData.getStrumlineIndex()];
//             if (holdGroup.members.length > 0) {
//                 for (holdNote in holdGroup.members) {
//                     if (holdNote.strumTime == note.noteData.time && holdNote.noteDirection == note.noteData.getDirection() && !holdNote.hitNote) {
//                         return holdNote;
//                     }
//                 }
//             }
//             else
//                 return null;
//         }
//         else 
//             return null;
//     }

//     function getNoteY(strumTime:Float, strumline:Strumline):Float {
//         return GRhythmUtil.getNoteY(strumTime, strumline.scrollSpeed, false, strumline.conductorInUse);
//     }
// }