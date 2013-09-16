$(function(){
  $('.share').click(function(e){
    e.preventDefault();
    var imgUrl = document.location.origin + $('img').attr('src');
    var nom = $(this).data('display-name') + "'s photo";
    var opt = {
      method: 'feed',
      picture: document.location.origin + $('img').attr('src'),
      source: $(this).attr('href'),
      name: nom,
      caption: 'usefixer.com',
      description: nom + ' ' + 'on Fixer'
    };
    FB.ui(opt, function(res){
    });
  });
});
