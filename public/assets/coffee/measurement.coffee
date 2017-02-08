$ ->
  $('#measurement-preview').hide()
  $('.m-preview').focus (e) ->
    name   = $(@).prop('name')
    title  = $(@).prop('title')
    $div = $('#measurement-preview')
    $img = $div.find('.preview-img img')
    $img.prop('src', "/assets/img/measurements/#{name}.jpg")
      .prop('alt', title)
    $div.find('.preview-desc').text(title)
    $div.show()

  $('.m-preview-none').focus (e) ->
    $div = $('#measurement-preview')
    $div.find('.preview-desc').text('')
    $div.hide()
