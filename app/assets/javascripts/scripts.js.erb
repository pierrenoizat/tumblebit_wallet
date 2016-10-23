var ready;
ready = function() {

	var codeSnippet = $('#snippet').data('code');
	var element = document.getElementById("contrat");
	//element.parentNode.removeChild(element);
	//document.body.appendChild(form);
	
	var form_field_value = $("#script_category").val()
	
	switch (form_field_value) {
	    case "time_locked_address":
	        codeSnippet = "&#60;expiry time&#62; CHECKLOCKTIMEVERIFY DROP &#60;public key&#62; CHECKSIG";
	        break;
	    case "time_locked_2fa":
	        codeSnippet = "IF &#60;service public key&#62; CHECKSIGVERIFY&#10; ELSE &#60;expiry time&#62; CHECKLOCKTIMEVERIFY DROP&#10; ENDIF&#10; &#60;user public key&#62; CHECKSIG";
	        break;
	    case "contract_oracle":
			select = document.getElementById("error_header");
			if (select) {
				select.innerHTML="";
			}
			select = document.getElementsByClassName("message_line")[0];
			if (select) {
				select.innerHTML="";
			}
	        codeSnippet = "&#60;contract_hash&#62; DROP 2 &#60;user pubkey&#62; &#60;oracle pubkey&#62; 2 CHECKMULTISIG";
	}
	element.innerHTML = codeSnippet;
	console.log(codeSnippet);
	console.log(form_field_value);
};

$(document).ready(ready);