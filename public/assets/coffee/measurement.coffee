$ ->
  $('#measurement-preview').hide()
  $('#guide-video').hide()
  $('#preview-desc').hide()

  $('.m-preview').focus (e) ->
    name   = $(@).prop('name')
    title  = $(@).prop('title')
    video  = $(@).data('video')
    label  = $(@).parent().prev().text()

    $div = $('#measurement-preview')
    $img = $div.find('.preview-img img')
    $img.prop('src', "/assets/img/measurements/#{name}.jpg")
      .prop('alt', title)
    $('#preview-desc .preview-desc-header').text(label)
    $('#preview-desc .preview-desc-body').text(title)
    $('#preview-desc').show()
    $div.show()
    if video
      $('#guide-video').prop('src', video).show()
    else
      $('#guide-video').prop('src', '').hide()

  $('.m-preview-none').focus (e) ->
    title  = $(@).prop('title') or ''
    label  = $(@).parent().prev().text() or ''

    $div = $('#measurement-preview')
    $div.hide()

    $('#preview-desc .preview-desc-header').text(label)
    $('#preview-desc .preview-desc-body').text(title)
    $('#preview-desc').show()

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
