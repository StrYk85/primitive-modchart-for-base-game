package vmodchart;

import funkin.play.PlayState;
import funkin.modding.module.Module;

class DemonstrationModule extends Module {
    public function new() {
        super('DemonstrationModule', 100, {state:PlayState});
    }

     function onUpdate(e) {
        super.onUpdate(e);
        final game = PlayState.instance;
        for (strumline in [game.opponentStrumline, game.playerStrumline]) {
            if (strumline != null) {
                for (a => strumNote in strumline.strumlineNotes.members) {
                    strumNote.y = 100 + Math.sin((game.conductorInUse.songPosition / 1000) + a) * 100;
                    strumNote.skew.y = Math.sin(game.conductorInUse.songPosition / 1000) * -25;
                }
            }
        }
    }
}