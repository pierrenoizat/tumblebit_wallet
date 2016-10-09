var ready;
ready = function() {
	
	$('#myModal').on('shown.bs.modal', function (event) {
	var button = $(event.relatedTarget); // Button that triggered the modal
	var modal = $(this)
	var qrcodeString = button.data('p2shaddress');
	modal.find('.modal-title').text(qrcodeString);
	new QRCode(document.getElementById("p2sh_qrcode"), qrcodeString);
	console.log(qrcodeString);
		
	});
	
}
	$(document).ready(ready);
