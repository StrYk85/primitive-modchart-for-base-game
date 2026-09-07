package vmodchart;

import flixel.math.FlxMath;
import funkin.Highscore;
import funkin.modding.module.Module;
import funkin.modding.events.HitNoteScriptEvent;
import funkin.modding.events.HoldNoteScriptEvent;
import funkin.ui.FullScreenScaleMode;
import funkin.play.PlayState;
import funkin.audio.FunkinSound;

class ModchartSetter extends Module {
    public function new() {
        super('ModchartSetter', 0, {state:PlayState});
    }

    private var game(get, never):PlayState;
    function get_game():PlayState {
        return PlayState.instance;
    }

    private function resetStrumlines() {
        final cutoutSize = FullScreenScaleMode.gameCutoutSize.x / 2.5;
        game.opponentStrumline.kill();
        game.playerStrumline.kill();

        game.opponentStrumline = new AdvancedStrumline(game.noteStyle, false, game.currentChart?.scrollSpeed);
        game.playerStrumline = new AdvancedStrumline(game.noteStyle, !game.isBotPlayMode, game.currentChart?.scrollSpeed);

        for (strumline in [game.opponentStrumline, game.playerStrumline]) {
            strumline.onNoteIncoming.add(game.onStrumlineNoteIncoming);
            strumline.zIndex = 1000;
            strumline.cameras = [game.camHUD];

            var xPos = strumline.isPlayer? (FlxG.width / 2 + Constants.STRUMLINE_X_OFFSET) + (cutoutSize / 2.0) : Constants.STRUMLINE_X_OFFSET + cutoutSize;
            var yPos = Constants.STRUMLINE_Y_OFFSET;
            if (Preferences.downscroll) yPos = FlxG.height - strumline.height - Constants.STRUMLINE_Y_OFFSET - strumline.noteStyle.getStrumlineOffsets()[1];

            strumline.setPosition(xPos, yPos);
            strumline.fadeInArrows();
        }
        game.add(game.opponentStrumline);
        game.add(game.playerStrumline);

        game.refresh();
        game.regenNoteData();
    }

    private function reprocessNotes(elapsed:Float) {
        final curStage:Null<Stage> = game.currentStage;
        final stageExists:Bool = curStage != null && !game.isMinimalMode;
        if (!stageExists) return;

        for (strumline in [game.opponentStrumline, game.playerStrumline]) {
            if (strumline == null || strumline.notes?.members == null) continue;
            if (strumline.toString() != 'PolymodScriptClass<vmodchart.objects.AdvancedStrumline>') continue; // this is so stupid

            final canPlay:Bool = strumline.isPlayer && !game.isBotPlayMode;
            final char:Null<BaseCharacter> = stageExists? (strumline.isPlayer? curStage.getBoyfriend() : curStage.getDad()) : null;
            for (sustain in strumline.holdSprites?.members) {
                if (sustain == null || !sustain.alive || sustain.noteData == null) continue;

                if (sustain.hitNote && !sustain.missedNote && sustain.sustainLength > 0) {
                    if (canPlay) {
                        if (sustain.scoreable) {
                            game.health += Constants.HEALTH_HOLD_BONUS_PER_SECOND * elapsed;
                            game.songScore += Constants.SCORE_HOLD_BONUS_PER_SECOND * elapsed;
                        }
                    }
                    if (char != null && char.isSinging()) {
                        char.holdTimer = 0;

                        if (strumline.oldSustainJitter) {
                            final conductor = strumline.conductorInUse;
                            if (strumline.holdTimer >= (conductor.stepLengthMs / 1000)) {
                                strumline.holdTimer = 0;
                                strumline.dummyNote.noteData = sustain.noteData;
                                strumline.dummyNote.strumTime = sustain.strumTime;
                                strumline.dummyNote.direction = sustain.noteDirection;
                                var ev = new HitNoteScriptEvent(strumline.dummyNote, 0, 0, canPlay? 'perfect-hold' : 'hold', false, 0);
                                curStage.dispatchToCharacters(ev);
                            }
                            else strumline.holdTimer += elapsed;
                        }
                    }
                }

                if (sustain.missedNote && !sustain.handledMiss) {
                    sustain.handledMiss = true;

                    if (sustain.scoreable) {
                        if (canPlay) {
                            if (sustain.scoreable && sustain != null) {
                                if (sustain.sustainLength > Constants.HOLD_DROP_PENALTY_THRESHOLD_MS) {
                                    var remainingLengthSec = sustain.sustainLength / Constants.MS_PER_SEC;
                                    var healthChangeUncapped = remainingLengthSec * Constants.HEALTH_HOLD_DROP_PENALTY_PER_SECOND;
                                    var healthChangeMax = Constants.HEALTH_HOLD_DROP_PENALTY_MAX + (sustain.hitNote ? Constants.HEALTH_MISS_PENALTY : 0);
                                    var healthChange = FlxMath.bound(healthChangeUncapped, 0, healthChangeMax);
                                    var scoreChange:Float = Constants.SCORE_HOLD_DROP_PENALTY_PER_SECOND * remainingLengthSec;

                                    var dummy = strumline.dummySustain;
                                    dummy.noteData = sustain.noteData;
                                    dummy.strumTime = sustain.strumTime;
                                    dummy.noteDirection = sustain.noteDirection;
                                    dummy.sustainLength = sustain.sustainLength;
                                    dummy.fullSustainLength = sustain.fullSustainLength;
                                    var ev:HoldNoteScriptEvent = new HoldNoteScriptEvent('NOTE_HOLD_DROP', dummy, healthChange, scoreChange, true, Highscore.tallies.combo);
                        
                                    game.dispatchEvent(ev);
                                    if (ev.eventCanceled) continue;
                                    
                                    game.applyScore(ev.score, '', ev.healthChange, ev.isComboBreak);
                                    if (ev.playSound) {
                                        if (game.vocals != null) {
                                            if (game.vocals.legacyVoiceSystem && !game.vocals.legacyVoiceUsesPlayer) game.vocals.opponentVolume = 0;
                                            game.vocals.playerVolume = 0;
                                        }
                                        FunkinSound.playOnce(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.5, 0.6));
                                    }
                                }
                            }
                        }
                        else 
                            if (char != null) char.playSingAnimation(sustain.noteData.getDirection(), true);
                    }
                }
            }
        }
    }

    function onStateChangeEnd(e) {
        super.onStateChangeEnd(e);
        resetStrumlines();
    }

    function onUpdate(e) {
        super.onUpdate(e);
        if (!game.isInCutscene) reprocessNotes(e.elapsed);
    }
}