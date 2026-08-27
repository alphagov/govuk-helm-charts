postgresql://{{ .username | urlquery }}:{{ .password | urlquery }}@{{ .host | toString }}
