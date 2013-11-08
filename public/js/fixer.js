$(function(){
  $('.share').click(function(e){
    e.preventDefault();
    FB.ui({
      method: 'feed',
      link: $(this).attr('href')
    }, function(res){});
  });
});
