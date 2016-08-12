$ ->
  order_id = location.pathname.split('/').pop()
  $('#clothes-recommend').load "/clothes/recommend?order_id=#{order_id}"
