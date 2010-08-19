function getCookie(c_name) {
	if (document.cookie.length>0) {
		c_start=document.cookie.indexOf(c_name + "=");
		if (c_start!=-1) { 
			c_start=c_start + c_name.length+1 ;
			c_end=document.cookie.indexOf(";",c_start);
			if (c_end==-1) c_end=document.cookie.length
				return unescape(document.cookie.substring(c_start,c_end));
		} 
	}
	return ""
}

function setCookie(c_name,value,expiredays) {
	var exdate=new Date();
	exdate.setDate(exdate.getDate()+expiredays);
	document.cookie=c_name+ "=" +escape(value)+((expiredays==null) ? "" : "; expires="+exdate.toUTCString());
}

function checkCookie() {
	var username=getCookie('authentication');
	var selectName=/^\w+/i
	// TODO innerhtml parsing/selecting correct entry does not work.
	var selectLoggedIn=/^[\w\s]+/
	var selectNotLoggedIn=/[\w\s]+$/
	if (username!=null && username!="") {
		// write to username
		document.getElementById("username").innerHTML=document.getElementById("username").innerHTML.search(selectLoggedIn)+username.match(selectName);
		//alert('Welcome again '+username.match(regex)+'!');
	}
	else {
		document.getElementById("username").innerHTML=document.getElementById("username").innerHTML.search(selectNotLoggedIn);
	}
}
