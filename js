<script>
$(document).ready(function(){
 $.ajax({
  type: "GET",
  url: "https://wucf-playlist-test.s3.amazonaws.com/hd2-1.xml",
  dataType: "xml",
  success: function(xml) {
   $(xml).find('NowPlaying').each(function(){
    var Col0 = $(this).find('Artist').text();
    var Col1 = $(this).find('Title').text();
    var Col2 = $(this).find('Agency').text();
    $('<tr></tr>').html('<th>'+Col0+'</th><td>'+Col1+'</td><td>'+Col2+'</td>').appendTo('#chart');
   });
  }
 });
});
</script>