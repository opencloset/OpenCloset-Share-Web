$ ->
  $('#measurement-preview').hide()
  $('#guide-video').hide()
  $('.m-preview').focus (e) ->
    name   = $(@).prop('name')
    title  = $(@).prop('title')
    video  = $(@).data('video')
    $div = $('#measurement-preview')
    $img = $div.find('.preview-img img')
    $img.prop('src', "/assets/img/measurements/#{name}.jpg")
      .prop('alt', title)
    $div.find('.preview-desc').text(title)
    $div.show()
    if video
      $('#guide-video').prop('src', video).show()
    else
      $('#guide-video').prop('src', '').hide()

  $('.m-preview-none').focus (e) ->
    $div = $('#measurement-preview')
    $div.find('.preview-desc').text('')
    $div.hide()
    $('#guide-video').prop('src', '').hide()

  $('.btn-size').click (e) ->
    $('.btn-size').removeClass('active')
    $(@).addClass('active')

    index = parseInt($(@).data('index'))
    size  = $(@).data('size')

    $table = $(@).closest('table')
    $table.find('td').removeClass('success')
    $(@).closest('table').find("tbody tr td:nth-child(#{index + 2})").toggleClass('success')

    which = $(@).data('which')
    $("input[name=#{which}_size]").val(size)

  $('.btn-size.active').trigger('click')
