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
