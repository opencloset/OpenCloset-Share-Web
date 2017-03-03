$ ->
  $("abbr.timeago").timeago()
  $('.btn-cancel:not(.disabled)').click (e) ->
    e.preventDefault()

    return unless confirm "삭제하시겠습니까?"

    $this = $(@)
    $this.addClass('disabled')

    $.ajax $this.data('url'),
      type: 'DELETE'
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
