/**
 * Socket.IO Actionscript client
 * 
 * @author Alexander Zalesov
 */

package com.zall.socketio {
	import flash.events.Event;
	
	public class SocketIOEvent extends Event {
		
		public static const MESSAGE : String = "message";
		public static const CONNECTED : String = "connected";
		public static const CONNECT_FAILED : String = "connect_failed";
		public static const ATTEMPT : String = "attempt";
		public static const DISCONNECTED : String = "disconnected";
		public static const RECONNECTING : String = "reconnecting";
		public static const ERROR : String = "error";
		
		public var data:Object;
		
		public function SocketIOEvent( type:String, messageData:Object=null, bubbles:Boolean=true, cancelable:Boolean=false){
			super(type, bubbles, cancelable);
			this.data = messageData;
		}
		
		override public function clone() : Event {
			return new SocketIOEvent(type, data, bubbles, cancelable);
		}
		
		
	}
	
}

