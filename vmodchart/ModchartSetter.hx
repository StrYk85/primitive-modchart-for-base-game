package vmodchart;

import flixel.math.FlxMath;
import funkin.Highscore;
import funkin.modding.module.Module;
import funkin.ui.FullScreenScaleMode;
import funkin.play.PlayState;
import funkin.audio.FunkinSound;
import funkin.modding.events.HoldNoteScriptEvent;
import funkin.modding.events.ScriptEventDispatcher;

class ModchartSetter extends Module {
    public function new() {
        super('ModchartSetter', 100, {state:PlayState});
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
            final xPos = strumline.isPlayer? (FlxG.width / 2 + Constants.STRUMLINE_X_OFFSET) + (cutoutSize / 2.0) : Constants.STRUMLINE_X_OFFSET + cutoutSize;
            final yPos = (Preferences.downscroll)? FlxG.height - strumline.height - Constants.STRUMLINE_Y_OFFSET - strumline.noteStyle.getStrumlineOffsets()[1] : Constants.STRUMLINE_Y_OFFSET;
            strumline.setPosition(xPos, yPos);
        }
        game.add(game.opponentStrumline);
        game.add(game.playerStrumline);

        game.refresh();
        game.regenNoteData();
    }

    private function reprocessNotes() {
        final curStage = game.currentStage;
        for (strumline in [game.opponentStrumline, game.playerStrumline]) {
            if (strumline == null || strumline.notes?.members == null) continue;
            if (strumline.toString() != 'PolymodScriptClass<vmodchart.objects.AdvancedStrumline>') continue;

            for (sustain in strumline.holdSprites?.members) {
                if (sustain == null || !sustain.alive || sustain.noteData == null) continue;

                if (sustain.hitNote && !sustain.missedNote && sustain.sustainLength > 0) {
                    final char = null;
                    if (curStage != null) char = strumline.isPlayer? curStage.getBoyfriend() : curStage.getDad();
                    if (strumline.isPlayer && !game.isBotPlayMode) {
                        if (sustain.scoreable) {
                            game.health += Constants.HEALTH_HOLD_BONUS_PER_SECOND * FlxG.elapsed;
                            game.songScore += Constants.SCORE_HOLD_BONUS_PER_SECOND * FlxG.elapsed;
                        }
                    }
                    else if (curStage != null && char != null && char.isSinging()) {
                        char.holdTimer = 0;

                        // final conductor = strumline.conductorInUse;
                        // if (strumline.holdTimer >= (conductor.stepLengthMs / 1000)) {
                        //     strumline.holdTimer = 0;
                        //     char.playSingAnimation(sustain.noteData.getDirection(), false);
                        // }
                        // else strumline.holdTimer += FlxG.elapsed;
                    }
                }

                if (sustain.missedNote && !sustain.handledMiss) {
                    sustain.handledMiss = true;

                    if (curStage != null && sustain.scoreable) {
                        if (strumline.isPlayer && !game.isBotPlayMode) {
                            final char = null;
                            if (curStage != null) char = strumline.isPlayer? curStage.getBoyfriend() : curStage.getDad();

                            if (sustain.scoreable) {
                                if (sustain.sustainLength > Constants.HOLD_DROP_PENALTY_THRESHOLD_MS) {
                                    trace('Player dropped a hold note, penalizing... (has hit: ${sustain.hitNote})');

                                    var remainingLengthSec = sustain.sustainLength / Constants.MS_PER_SEC;
                                    var healthChangeUncapped = remainingLengthSec * Constants.HEALTH_HOLD_DROP_PENALTY_PER_SECOND;
                                    // If the base note of the hold was missed, don't penalize them more on top of that.
                                    var healthChangeMax = Constants.HEALTH_HOLD_DROP_PENALTY_MAX + (sustain.hitNote ? Constants.HEALTH_MISS_PENALTY : 0);
                                    var healthChange = FlxMath.bound(healthChangeUncapped, 0, healthChangeMax);
                                    var scoreChange:Float = Constants.SCORE_HOLD_DROP_PENALTY_PER_SECOND * remainingLengthSec;

                                    strumline.dummySustain.strumTime = sustain.strumTime;
                                    strumline.dummySustain.noteDirection = sustain.noteDirection;
                                    strumline.dummySustain.sustainLength = sustain.sustainLength;
                                    strumline.dummySustain.fullSustainLength = sustain.fullSustainLength;
                                    var ev:HoldNoteScriptEvent = new HoldNoteScriptEvent('NOTE_HOLD_DROP', strumline.dummySustain, healthChange, scoreChange, true, Highscore.tallies.combo);
                                    PlayState.instance.dispatchEvent(ev);
                                    // ScriptEventDispatcher.callEvent(game.currentSong, ev);
                                    if (ev.eventCanceled) continue;

                                    trace('Penalizing score by ${ev.score} and health by ${ev.healthChange} for dropping hold note (is combo break: ${ev.isComboBreak})!');
                                    game.applyScore(ev.score, '', ev.healthChange, ev.isComboBreak);

                                    if (ev.playSound) {
                                        if (game.vocals != null) {
                                            if (game.vocals.legacyVoiceSystem && !game.vocals.legacyVoiceUsesPlayer) game.vocals.opponentVolume = 0;
                                            game.vocals.playerVolume = 0;
                                        }
                                        FunkinSound.playOnce(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.5, 0.6));
                                    }
                                }
                                else
                                    trace('Hold note too short, not penalizing...');
                            }
                        }
                        else 
                            char.playSingAnimation(sustain.noteData.getDirection(), true);
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
        reprocessNotes();
        if (game.playerStrumline != null) {
            for (strumNote in game.playerStrumline.strumlineNotes.members) {
                strumNote.angle = Math.sin(game.conductorInUse.songPosition / 1000) * 50;
                //strumNote.skew.x = strumNote.angle;
            }
        }
    }
}