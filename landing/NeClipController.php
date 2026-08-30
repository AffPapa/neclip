<?php

namespace App\Http\Controllers\Affpapa;

use App\Http\Controllers\Controller;
use Illuminate\Contracts\View\View;

class NeClipController extends Controller
{
    public function show(): View
    {
        return view('affpapa.neclip');
    }
}
