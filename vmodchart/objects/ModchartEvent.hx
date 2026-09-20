package vmodchart.objects;

class ModchartEvent {
    public var note:Dynamic;
    public var strumlineNote:StrumlineNote;
    public var direction:NoteDirection;
    public var isSustain:Bool;
    public var notePosition:Float;
    public var strumPosition:FlxPoint;

    public var eventCanceled:Bool;
    
    public function new(note:Dynamic, strumlineNote:StrumlineNote, direction:NoteDirection, isSustain:Bool, notePosition:Float, strumPosition:FlxPoint) {
        this.eventCanceled = false;

        this.note = note;
        this.strumlineNote = strumlineNote;
        this.direction = direction;
        this.isSustain = isSustain;
        this.notePosition = notePosition;
        this.strumPosition = strumPosition;
    }

    public function cancel() {
        eventCanceled = true;
    }
}